//
//  UkeDrawingPointsParser.m
//  ZMUke
//
//  Created by liqian on 2019/6/24.
//  Copyright © 2019 zmlearn. All rights reserved.
//

#import "UkeDrawingPointsParser.h"

@interface UkeDrawingPointsParser ()
@property (nonatomic, copy, nullable) __block NSString *currentActionId; // 当前画笔id
@property (nonatomic, copy, nullable) __block NSString *currentBrushType; // 当前画笔类型
@property (nonatomic, assign) __block UkeDrawingState currentDrawingState; // 当前绘画状态

@property (nonatomic, strong) __block NSValue *startPoint; // 开始点
@property (nonatomic, strong) __block NSMutableArray<NSValue *> *realDrawPoints; // 真正用于绘画的坐标点数组

@property (nonatomic, assign) BOOL isFillPath;
@property (nonatomic, assign) BOOL isNormalShape;
@property (nonatomic, assign) CGFloat lineWidth;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, assign) BOOL forceEndPreviousPath;

@end

@implementation UkeDrawingPointsParser

- (instancetype)init {
    self = [super init];
    if (self) {
        _scaleX = 1.0;
        _scaleY = 1.0;
        _realDrawPoints = [NSMutableArray array];
        _currentDrawingState = UkeDrawingStateUnknown;
    }
    return self;
}

- (void)parseWithPoints:(NSArray<NSArray *> *)points
             completion:(void(^)(UkeDrawingPointsParser *parser))completionHandler; {
    
    if (![points isPracticalArray]) {
        return;
    }
    
    [points enumerateObjectsUsingBlock:^(NSArray *singlePoint, NSUInteger index, BOOL * _Nonnull stop) {
        if (singlePoint.count < 2) {
            return; // 相当于for循环的continue
        }
        
        // 画笔序列号
        NSString *actionId = nil;
        if (singlePoint.count >= 3) {
            if ([singlePoint[2] isValidStringOrNumber]) {
                actionId = singlePoint[2];
            }
        }
        
        // 如果该点actionId不等于当前记录的actionId，则强制结束前一个路径
        if (self.currentActionId && self.currentActionId.integerValue != actionId.integerValue) {
            // 强制结束上一个路径
            [self outputPathDataForceEnd:YES completion:completionHandler];
        }
        
        // 画笔类型
        NSString *brushType = nil;
        if (singlePoint.count >= 4) {
            brushType = singlePoint[3];
        }
        
        if ([brushType isPracticalString]) {
            // 去除杂数据
            if ([brushType isEqualToString:@"publisherTime"]) {
                return;
            }
            
            if ([kUkeAllDrawingBrushTypes containsObject:brushType]) {
#pragma mark - 起始点
                self.currentActionId = actionId;
                self.currentBrushType = brushType;
                self.currentDrawingState = UkeDrawingStateStart;
                
                NSArray *brushInfo = nil; // 画笔信息：如粗细，颜色等
                if (singlePoint.count >= 5) {
                    if ([singlePoint[4] isPracticalArray]) {
                        brushInfo = singlePoint[4];
                    }
                }
                [self parseStartPointWithSinglePoint:singlePoint brushInfo:brushInfo];
                
                // 某些特殊画笔类型中，起始点中会包含结束点
                [self parseSpecialStartPointWithSinglePoint:singlePoint brushInfo:brushInfo completion:completionHandler];
            }else {
        #pragma mark - 中间点 或 结束点
                [self parseMiddlePointOrEndPointWithSinglePoint:singlePoint completion:completionHandler];
            }
        }else {
#pragma mark - 中间点 或 结束点
            [self parseMiddlePointOrEndPointWithSinglePoint:singlePoint completion:completionHandler];
        }
    }];
    
    // 如果数据解析完了，但是当前状态还是 开始绘画 或 绘画中，则主动触发绘画动作
    if (self.currentDrawingState > UkeDrawingStateUnknown) {
        // 结束当前路径
        [self outputPathDataForceEnd:NO completion:completionHandler];
    }
}

// 解析开始点
- (void)parseStartPointWithSinglePoint:(NSArray *)singlePoint
                             brushInfo:(nullable NSArray *)brushInfo {
    if (self.currentBrushType == nil) {
        return;
    }
    if ([brushInfo isPracticalArray] == NO) {
        return;
    }
    
    // 取绘画坐标点
    if ([singlePoint[0] isValidStringOrNumber] && [singlePoint[1] isValidStringOrNumber]) {
        NSValue *point = [NSValue valueWithCGPoint:CGPointMake([singlePoint[0] floatValue]*self.scaleX, [singlePoint[1] floatValue]*self.scaleY)];
        self.startPoint = point;
    }else {
        self.startPoint = [NSValue valueWithCGPoint:CGPointMake(0, 0)];
    }
    
    // 解析颜色、线宽等数据
    CGFloat width = 0;
    UIColor *color = nil;
    if (brushInfo) {
        if (brushInfo.count >= 1) {
            if ([brushInfo[0] isValidStringOrNumber]) {
                width = [brushInfo[0] floatValue];
            }
        }
        
        if (brushInfo.count >= 2) {
            NSString *hexString = nil;
            if ([self.currentBrushType isEqualToString:kUkeAllDrawingBrushTypes[2]] || // 圆
                [self.currentBrushType isEqualToString:kUkeAllDrawingBrushTypes[3]]) { // 框
                // 粗细、是否填充、颜色、是否正多边形
                if (brushInfo.count >= 3) {
                    hexString = brushInfo[2];
                }
                
                self.isFillPath = [brushInfo[1] boolValue];
                if (brushInfo.count >= 4) {
                    self.isNormalShape = [brushInfo[3] boolValue];
                }
            }else {
                // 颜色
                hexString = brushInfo[1];
            }
            
            if ([hexString isPracticalString]) {
                color = [UIColor colorWithHexString:hexString];
                if (color == nil) {
                    color = [UIColor colorWithHexString:@"ef4c4f"];
                }
            }else {
                color = [UIColor colorWithHexString:@"ef4c4f"];
            }
            
            if ([self.currentBrushType isEqualToString:kUkeAllDrawingBrushTypes[9]]) { // 五角星
                // 粗细、颜色、是否填充
                if (brushInfo.count >= 3) {
                    if ([brushInfo[2] isValidStringOrNumber]) {
                        self.isFillPath = [brushInfo[2] boolValue];
                    }
                }
            }
            
            if ([self.currentBrushType isEqualToString:kUkeAllDrawingBrushTypes[8]]) { // 三角形
                if (brushInfo.count >= 8) {
                    if ([brushInfo[7] isValidStringOrNumber]) {
                        self.isFillPath = [brushInfo[7] boolValue];
                    }
                    if ([brushInfo[6] isValidStringOrNumber]) {
                        self.isNormalShape = [brushInfo[6] boolValue];
                    }
                }
            }
        }
        
        if (width > 0) {
            self.lineWidth = width*self.scaleX;
        }
        if (color) {
            self.color = color;
        }
    }
}

// 解析特殊起始点
- (void)parseSpecialStartPointWithSinglePoint:(NSArray *)singlePoint
                               brushInfo:(nullable NSArray *)brushInfo
                                   completion:(void(^)(UkeDrawingPointsParser *parser))completionHandler {
    if (self.currentBrushType == nil) {
        return;
    }
    
    if ([self.currentBrushType isEqualToString:kUkeAllDrawingBrushTypes[10]]) { // pressurepen
        return;
    }
    
    if (singlePoint.count < 6) {
        return;
    }
    
    // 终止符
    NSString *terminalFlag = singlePoint[5];
    // 去除杂数据
    if ([terminalFlag isPracticalString]&&[terminalFlag isEqualToString:@"publisherTime"]) {
        return;
    }
    // 判断是否是真的终止点
    if ([terminalFlag isValidStringOrNumber]&&terminalFlag.boolValue == NO) {
        return;
    }
    
    BOOL isSpecialStartPoint = YES;
    
    if ([self.currentBrushType isEqualToString:kUkeAllDrawingBrushTypes[8]]) { // 三角形
        // 三角形的剩下两个点在drawInfo里面
        if (brushInfo.count >= 6) {
            if ([brushInfo[2] isValidStringOrNumber] && [brushInfo[3] isValidStringOrNumber]) {
                NSValue *point1 = [NSValue valueWithCGPoint:CGPointMake([brushInfo[2] floatValue]*self.scaleX, [brushInfo[3] floatValue]*self.scaleY)];
                [self.realDrawPoints addObject:point1];
            }
            if ([brushInfo[4] isValidStringOrNumber] && [brushInfo[5] isValidStringOrNumber]) {
                NSValue *point2 = [NSValue valueWithCGPoint:CGPointMake([brushInfo[4] floatValue]*self.scaleX, [brushInfo[5] floatValue]*self.scaleY)];
                [self.realDrawPoints addObject:point2];
            }
        }
    }else if ([self.currentBrushType isEqualToString:kUkeAllDrawingBrushTypes[7]]) { // 箭头
        // 箭头的终点在drawInfo里面
        if (brushInfo.count >= 4) {
            if ([brushInfo[2] isValidStringOrNumber] && [brushInfo[3] isValidStringOrNumber]) {
                NSValue *endPoint = [NSValue valueWithCGPoint:CGPointMake([brushInfo[2] floatValue]*self.scaleX, [brushInfo[3] floatValue]*self.scaleY)];
                [self.realDrawPoints addObject:endPoint];
            }
        }
    }else if ([self.currentBrushType isEqualToString:kUkeAllDrawingBrushTypes[4]]) { // 文字
        // 文本在drawInfo里面
        if (singlePoint.count >= 7) {
            if ([singlePoint[6] isPracticalString]) {
                self.text = singlePoint[6];
            }
        }
    } else {
        isSpecialStartPoint = NO;
    }
    
    if (isSpecialStartPoint) {
        self.currentDrawingState = self.currentDrawingState|UkeDrawingStateEnd;

        // 结束当前路径
        [self outputPathDataForceEnd:NO completion:completionHandler];
    }
}

// 解析中间点或结束点
- (void)parseMiddlePointOrEndPointWithSinglePoint:(NSArray *)singlePoint
                                       completion:(void(^)(UkeDrawingPointsParser *parser))completionHandler {
    if (self.currentBrushType == nil) {
        return;
    }
    
    // 取绘画坐标点
    if (singlePoint.count >= 2) {
        if ([singlePoint[0] isValidStringOrNumber] && [singlePoint[1] isValidStringOrNumber]) {
            NSValue *point = [NSValue valueWithCGPoint:CGPointMake([singlePoint[0] floatValue]*self.scaleX, [singlePoint[1] floatValue]*self.scaleY)];
            [self.realDrawPoints addObject:point];
        }
    }
    
    if ([self.currentBrushType isEqualToString:kUkeAllDrawingBrushTypes[10]]) { // pressurepen
        if (singlePoint.count == 4) { // 中间点
            self.currentDrawingState = self.currentDrawingState|UkeDrawingStateDrawing;
        }else if (singlePoint.count == 5) { // 结束点
            // 终止符
            NSString *terminalFlag = singlePoint[4];
            // 去除杂数据
            if ([terminalFlag isPracticalString]&&[terminalFlag isEqualToString:@"publisherTime"]) {
                return;
            }
            // 判断是否是真的终止点
            if ([terminalFlag isValidStringOrNumber]&&terminalFlag.boolValue == NO) {
                return;
            }
            
            self.currentDrawingState = self.currentDrawingState|UkeDrawingStateEnd;
            // 结束当前路径
            [self outputPathDataForceEnd:NO completion:completionHandler];
        }
    }else {
        if (singlePoint.count == 3) { // 中间点
            self.currentDrawingState = self.currentDrawingState|UkeDrawingStateDrawing;
        }else if (singlePoint.count == 4) { // 结束点
            // 终止符
            NSString *terminalFlag = singlePoint[3];
            // 去除杂数据
            if ([terminalFlag isPracticalString]&&[terminalFlag isEqualToString:@"publisherTime"]) {
                return;
            }
            // 判断是否是真的终止点
            if ([terminalFlag isValidStringOrNumber]&&terminalFlag.boolValue == NO) {
                return;
            }
            
            self.currentDrawingState = self.currentDrawingState|UkeDrawingStateEnd;
            // 结束当前路径
            [self outputPathDataForceEnd:NO completion:completionHandler];
        }
    }
}

// 输出数据点供绘图使用
- (void)outputPathDataForceEnd:(BOOL)forcedEnd
                        completion:(void(^)(UkeDrawingPointsParser *parser))completionHandler {
    if (forcedEnd) {
        self.forceEndPreviousPath = YES;
    }
    
    // 数据点优化，画线段、椭圆、矩形框、框选删除、箭头、五角星等不需要每个点都画，在同一个currentDrawPoints中，只需要取最后一个点即可。
    if (self.realDrawPoints.count > 1) {
        if (self.brushType != UkeDrawingBrushTypeBrush &&
            self.brushType != UkeDrawingBrushTypePressurePen &&
            self.brushType != UkeDrawingBrushTypeText &&
            self.brushType != UkeDrawingBrushTypeEraser &&
            self.brushType != UkeDrawingBrushTypeTriangle) {
            
            self.realDrawPoints = [NSMutableArray arrayWithObject:self.realDrawPoints.lastObject];
        }
    }
    
    // 回调
    __weak typeof(self)weakSelf = self;
    if (completionHandler) {
        completionHandler(weakSelf);
    }
    
    // 清除对应数据
    self.currentDrawingState = UkeDrawingStateUnknown;
    self.realDrawPoints = [NSMutableArray array];
    self.forceEndPreviousPath = NO;
    self.text = nil;

    // 如果是结束路径
    if (self.currentDrawingState&UkeDrawingStateEnd || forcedEnd) {
        self.currentActionId = nil;
        self.currentBrushType = nil;
        self.lineWidth = 0;
        self.color = nil;
        self.isFillPath = NO;
        self.isNormalShape = NO;
        self.startPoint = nil;
    }
}

/*
- (NSInteger)numberWithHexString:(NSString *)hexString {
    const char *hexChar = [hexString cStringUsingEncoding:NSUTF8StringEncoding];
    int hexNumber;
    sscanf(hexChar, "%x", &hexNumber);
    return (NSInteger)hexNumber;
}
*/

#pragma mark - Getters
- (UkeDrawingBrushType)brushType {
    UkeDrawingBrushType brushType = UkeDrawingBrushTypeUnKnown;
    if ([self.currentBrushType isPracticalString]) {
        brushType = [kUkeAllDrawingBrushTypes indexOfObject:self.currentBrushType];
    }
    return brushType;
}

- (UkeDrawingState)drawingState {
    return self.currentDrawingState;
}

@end
