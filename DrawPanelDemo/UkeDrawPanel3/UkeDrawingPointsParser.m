//
//  UkeDrawingPointsParser.m
//  ZMUke
//
//  Created by liqian on 2019/6/24.
//  Copyright © 2019 zmlearn. All rights reserved.
//

#import "UkeDrawingPointsParser.h"
#import "UIColor+Extension.h"

@interface NSString (BrushType)
- (UkeDrawingBrushType)brushType_int;
@end

@implementation NSString (BrushType)

- (UkeDrawingBrushType)brushType_int {
    return brushTypeFromNSString(self);
}

@end


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
                
                // 某些特殊画笔类型中，起始点数据中会包含所有点的数据
                [self parseSpecialStartPointWithSinglePoint:singlePoint brushInfo:brushInfo completion:completionHandler];
            } else {
        #pragma mark - 中间点 或 结束点
                [self parseMiddlePointOrEndPointWithSinglePoint:singlePoint completion:completionHandler];
            }
        } else {
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
            if (self.brushType == UkeDrawingBrushTypeEllipse || // 圆
                self.brushType == UkeDrawingBrushTypeRectangle || // 框
                self.brushType == UkeDrawingBrushTypeCircle_edit || // 可编辑同心圆
                self.brushType == UkeDrawingBrushTypeEllipse_edit || // 可编辑焦点椭圆
                self.brushType == UkeDrawingBrushTypeLine_edit || // 可编辑线段
                self.brushType == UkeDrawingBrushTypeLineArrow_edit || // 可编辑箭头
                self.brushType == UkeDrawingBrushTypeLineDash_edit || // 可编辑虚线
                self.brushType == UkeDrawingBrushTypeCoordSys_edit) { // 坐标系
                // [粗细, 是否填充, 颜色, 是否正多边形]
                if (brushInfo.count >= 3) {
                    hexString = brushInfo[2];
                }
                
                self.isFillPath = [brushInfo[1] boolValue];
                if (brushInfo.count >= 4) {
                    self.isNormalShape = [brushInfo[3] boolValue];
                }
            } else {
                // [粗细, 颜色]
                hexString = brushInfo[1];
            }
            
            if ([hexString isPracticalString]) {
                color = [UIColor colorWithHexString:hexString];
            }
            
            if (color == nil) {
                color = [UIColor colorWithHexString:@"ef4c4f"];
            }
            
            if (self.brushType == UkeDrawingBrushTypeStar) { // 五角星
                // 粗细、颜色、是否填充
                if (brushInfo.count >= 3) {
                    if ([brushInfo[2] isValidStringOrNumber]) {
                        self.isFillPath = [brushInfo[2] boolValue];
                    }
                }
            }
            
            if (self.brushType == UkeDrawingBrushTypeTriangle) { // 三角形
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

/// 解析特殊起始点
- (void)parseSpecialStartPointWithSinglePoint:(NSArray *)singlePoint
                               brushInfo:(nullable NSArray *)brushInfo
                                   completion:(void(^)(UkeDrawingPointsParser *parser))completionHandler {
    if (self.currentBrushType == nil) {
        return;
    }
    
    if (self.brushType == UkeDrawingBrushTypePressurePen) { // pressurepen
        return;
    }
    
    if (singlePoint.count < 6) {
        return;
    }
    
    if (self.brushType == UkeDrawingBrushTypePolygon_edit || // 可编辑多边形
        self.brushType == UkeDrawingBrushTypeCircle_edit || // 可编辑同心圆
        self.brushType == UkeDrawingBrushTypeEllipse_edit || // 可编辑焦点椭圆
        self.brushType == UkeDrawingBrushTypeLine_edit || // 可编辑线段
        self.brushType == UkeDrawingBrushTypeLineArrow_edit || // 可编辑箭头
        self.brushType == UkeDrawingBrushTypeLineDash_edit // 可编辑虚线
        ) {
        
        [self parsePolygon_editWithSinglePoint:singlePoint brushInfo:brushInfo completion:completionHandler];
        
        return;
    } else if (self.brushType == UkeDrawingBrushTypeCoordSys_edit) { // 可编辑坐标系
        [self parseCoordSys_editWithSinglePoint:singlePoint brushInfo:brushInfo completion:completionHandler];
       
        return;
    } else if (self.brushType == UkeDrawingBrushTypeText_edit) { // 可编辑文字
        [self parseText_editWithSinglePoint:singlePoint brushInfo:brushInfo completion:completionHandler];
        
        return;
    } else if (self.brushType == UkeDrawingBrushTypeEdit_regular) { // 对现有的图形进行编辑（移动、缩放、单点移动）
        [self parseEdit_regularWithSinglePoint:singlePoint brushInfo:brushInfo completion:completionHandler];
        
        return;
    } else if (self.brushType == UkeDrawingBrushTypeEdit_delete) { // 删除指定图形
        [self parseEdit_deleteWithSinglePoint:singlePoint brushInfo:brushInfo completion:completionHandler];
       
        return;
    } else if (self.brushType == UkeDrawingBrushTypeEdit_deletePage) { // 删除整页
        self.currentDrawingState = self.currentDrawingState|UkeDrawingStateEnd;
        // 结束当前路径
        [self outputPathDataForceEnd:NO completion:completionHandler];
        return;
    }
    
    
    // 1.0版本是有终止符的，这里保留
    
    // 终止符
    NSString *terminalFlag = singlePoint[5];
    if ([terminalFlag isValidStringOrNumber] == NO) {
        return;
    }
    
    // 去除杂数据
    if ([terminalFlag isEqualToString:@"publisherTime"]) {
        return;
    }
    // 判断是否是真的终止点
    if (terminalFlag.boolValue == NO) {
        return;
    }
    
    if (self.brushType == UkeDrawingBrushTypeTriangle) { // 三角形
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
    } else if (self.brushType == UkeDrawingBrushTypeLineArrow) { // 箭头
        // 箭头的终点在drawInfo里面
        if (brushInfo.count >= 4) {
            if ([brushInfo[2] isValidStringOrNumber] && [brushInfo[3] isValidStringOrNumber]) {
                NSValue *endPoint = [NSValue valueWithCGPoint:CGPointMake([brushInfo[2] floatValue]*self.scaleX, [brushInfo[3] floatValue]*self.scaleY)];
                [self.realDrawPoints addObject:endPoint];
            }
        }
    } else if (self.brushType == UkeDrawingBrushTypeText) { // 文字
        // 文本在drawInfo里面
        if (singlePoint.count >= 7) {
            if ([singlePoint[6] isPracticalString]) {
                self.text = singlePoint[6];
            }
        }
    }
    
    self.currentDrawingState = self.currentDrawingState|UkeDrawingStateEnd;

    // 结束当前路径
    [self outputPathDataForceEnd:NO completion:completionHandler];
}

/// 解析可编辑的多边形、同心圆、焦点椭圆、线段、箭头、虚线
- (void)parsePolygon_editWithSinglePoint:(NSArray *)singlePoint
                               brushInfo:(nullable NSArray *)brushInfo
                              completion:(void(^)(UkeDrawingPointsParser *parser))completionHandler {
    if (singlePoint.count >= 7) {
        NSArray *polygonInfo = singlePoint[6];
        if (polygonInfo.count >= 3) {
            NSString *identifier = polygonInfo[0];
            self.identifier = identifier;
            
            NSArray *polygonPoints = polygonInfo[1];
            if (polygonPoints.count >= 2) {
                if ([polygonPoints[0] isValidStringOrNumber] && [polygonPoints[1] isValidStringOrNumber]) {
                    self.startPoint = [NSValue valueWithCGPoint:CGPointMake([polygonPoints[0] floatValue]*self.scaleX, [polygonPoints[1] floatValue]*self.scaleY)];
                }
                
                for (int i = 2; (i+1) < polygonPoints.count; i+=2) { // 保证解析的xy点是偶数对的，如：不能只出现x不出现y
                    
                    if ([polygonPoints[i] isValidStringOrNumber] &&
                        [polygonPoints[i+1] isValidStringOrNumber]) {
                        
                        NSValue *point = [NSValue valueWithCGPoint:CGPointMake([polygonPoints[i] floatValue]*self.scaleX, [polygonPoints[i+1] floatValue]*self.scaleY)];
                        [self.realDrawPoints addObject:point];
                    }
                }
                
                
                if ([polygonInfo[2] isValidStringOrNumber]) {
                    self.showVertex = [polygonInfo[2] boolValue];
                }
                
                self.currentDrawingState = self.currentDrawingState|UkeDrawingStateDrawing|UkeDrawingStateEnd;
                // 结束当前路径
                [self outputPathDataForceEnd:NO completion:completionHandler];
            }
        }
    }
}

// 解析可编辑的坐标系
- (void)parseCoordSys_editWithSinglePoint:(NSArray *)singlePoint
                               brushInfo:(nullable NSArray *)brushInfo
                              completion:(void(^)(UkeDrawingPointsParser *parser))completionHandler {
    if (singlePoint.count >= 7) {
        NSArray *polygonInfo = singlePoint[6];
        if (polygonInfo.count >= 2) {
            NSString *identifier = polygonInfo[0];
            self.identifier = identifier;
            
            NSArray *polygonPoints = polygonInfo[1];
            if (polygonPoints.count >= 2) {
                if ([polygonPoints[0] isValidStringOrNumber] && [polygonPoints[1] isValidStringOrNumber]) {
                    self.startPoint = [NSValue valueWithCGPoint:CGPointMake([polygonPoints[0] floatValue]*self.scaleX, [polygonPoints[1] floatValue]*self.scaleY)];
                }
                
                for (int i = 2; (i+1) < polygonPoints.count; i+=2) { // 保证解析的xy点是偶数对的，如：不能只出现x不出现y
                    
                    if ([polygonPoints[i] isValidStringOrNumber] &&
                        [polygonPoints[i+1] isValidStringOrNumber]) {
                        
                        NSValue *point = [NSValue valueWithCGPoint:CGPointMake([polygonPoints[i] floatValue]*self.scaleX, [polygonPoints[i+1] floatValue]*self.scaleY)];
                        [self.realDrawPoints addObject:point];
                    }
                }
                
                if (self.realDrawPoints.count == 0) return;
                
                // 画坐标系不太一样，需要把x、y坐标系四个顶点全部计算出来
                // 这两个点是传过来的原始点
                CGPoint originalPoint1 = [self.startPoint CGPointValue];
                CGPoint originalPoint2 = [self.realDrawPoints.firstObject CGPointValue];
                
                CGFloat x_length = 2 * fabs(originalPoint2.x - originalPoint1.x); // x轴长
                CGFloat y_length = 2 * fabs(originalPoint2.y - originalPoint1.y); // y轴长
                
                CGPoint xLeft = CGPointMake(originalPoint1.x - x_length*0.5, originalPoint1.y);
                CGPoint xRight = CGPointMake(originalPoint1.x + x_length*0.5, originalPoint1.y);
                
                CGPoint yBottom = CGPointMake(originalPoint1.x, originalPoint1.y + y_length*0.5);
                CGPoint yTop = CGPointMake(originalPoint1.x, originalPoint1.y - y_length*0.5);

                self.realDrawPoints = @[
                    [NSValue valueWithCGPoint:xLeft],
                    [NSValue valueWithCGPoint:xRight],
                    [NSValue valueWithCGPoint:yBottom],
                    [NSValue valueWithCGPoint:yTop],
                ].mutableCopy;
                
                self.currentDrawingState = self.currentDrawingState|UkeDrawingStateDrawing|UkeDrawingStateEnd;
                // 结束当前路径
                [self outputPathDataForceEnd:NO completion:completionHandler];
            }
        }
    }
}

// 解析可编辑的文字
- (void)parseText_editWithSinglePoint:(NSArray *)singlePoint
                               brushInfo:(nullable NSArray *)brushInfo
                              completion:(void(^)(UkeDrawingPointsParser *parser))completionHandler {
    if (singlePoint.count >= 7) {
        NSArray *polygonInfo = singlePoint[6];
        if (polygonInfo.count >= 2) {
            NSString *identifier = polygonInfo[0];
            self.identifier = identifier;
            self.text = polygonInfo[1];
            
            self.currentDrawingState = self.currentDrawingState|UkeDrawingStateDrawing|UkeDrawingStateEnd;
            // 结束当前路径
            [self outputPathDataForceEnd:NO completion:completionHandler];
        }
    }
}

- (void)parseEdit_regularWithSinglePoint:(NSArray *)singlePoint
                            brushInfo:(nullable NSArray *)brushInfo
                           completion:(void(^)(UkeDrawingPointsParser *parser))completionHandler {
    if (singlePoint.count >= 7) {
        
        UkeGraphicEditType editType;
        NSInteger singlePointIndex = NSNotFound;
        CGPoint translation = CGPointZero;
        CGPoint scale = CGPointZero;
        NSString *text = nil;
        
        if ([singlePoint[0] isValidStringOrNumber] && [singlePoint[1] isValidStringOrNumber]) {
            translation = CGPointMake([singlePoint[0] floatValue]*self.scaleX, [singlePoint[1] floatValue]*self.scaleY);
        }
        
        NSArray *polygonInfo = singlePoint[6];
        if (polygonInfo.count >= 2) {
            self.identifier = polygonInfo[0];
            
            NSNumber *editTypeNum = polygonInfo[1];
            if (editTypeNum.integerValue == 0) { // 整体移动
                editType = UkeGraphicEditTypeWholeTranslation;
            } else if (editTypeNum.integerValue == 1) { // 缩放
                editType = UkeGraphicEditTypeScale;
            } else if (editTypeNum.integerValue == 2) { // 单点移动
                editType = UkeGraphicEditTypeSinglePointTranslation;
            } else if (editTypeNum.integerValue == 3) { // 修改文字
                editType = UkeGraphicEditTypeEditText;
            } else {
                editType = UkeGraphicEditTypeUnknown;
            }
            
            BOOL error = YES;
            switch (editType) {
                case UkeGraphicEditTypeWholeTranslation: {
                    error = NO;
                } break;
                
                case UkeGraphicEditTypeScale: {
                    if (polygonInfo.count >= 4) {
                        if ([polygonInfo[2] isValidStringOrNumber] && [polygonInfo[3] isValidStringOrNumber]) {
                            CGFloat scaleX = [polygonInfo[2] floatValue];
                            CGFloat scaleY = [polygonInfo[3] floatValue];
                            scale = CGPointMake(scaleX, scaleY);
                            
                            error = NO;
                        }
                    }
                } break;
                    
                case UkeGraphicEditTypeSinglePointTranslation: {
                    if (polygonInfo.count >= 3) {
                        if ([polygonInfo[2] isValidStringOrNumber]) {
                            singlePointIndex = [polygonInfo[2] integerValue];
                            
                            error = NO;
                        }
                    }
                } break;
                    
                case UkeGraphicEditTypeEditText: {
                    if (polygonInfo.count >= 3) {
                        if ([polygonInfo[2] isValidString]) {
                            text = polygonInfo[2];
                            
                            error = NO;
                        }
                    }
                } break;
                    
                default: {
                    error = YES;
                } break;
            }
            
            if (error == NO) {
                UkeGraphicEditInfo *editInfo = [[UkeGraphicEditInfo alloc] init];
                editInfo.editType = editType;
                editInfo.singlePointIndex = singlePointIndex;
                editInfo.translation = translation;
                editInfo.scale = scale;
                editInfo.text = text;
                
                self.editInfo = editInfo;
                
                self.currentDrawingState = self.currentDrawingState|UkeDrawingStateDrawing|UkeDrawingStateEnd;
                // 结束当前路径
                [self outputPathDataForceEnd:NO completion:completionHandler];
            }
        }
    }
}

- (void)parseEdit_deleteWithSinglePoint:(NSArray *)singlePoint
                               brushInfo:(nullable NSArray *)brushInfo
                              completion:(void(^)(UkeDrawingPointsParser *parser))completionHandler {
    if (singlePoint.count >= 7) {
        NSArray *polygonInfo = singlePoint[6];
        if ([polygonInfo isPracticalArray]) {
            self.delete_ids = [NSSet setWithArray:polygonInfo];
            
            self.currentDrawingState = self.currentDrawingState|UkeDrawingStateDrawing|UkeDrawingStateEnd;
            // 结束当前路径
            [self outputPathDataForceEnd:NO completion:completionHandler];
        }
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
    
    if (self.brushType == UkeDrawingBrushTypePressurePen) { // pressurepen
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
    
    if (self.currentDrawingState == UkeDrawingStateUnknown) {
        return;
    }
    
    if (forcedEnd) {
        self.forceEndPreviousPath = YES;
    }
    
    // 数据点优化，画线段、椭圆、矩形框、框选删除、箭头、五角星等不需要每个点都画，在同一个currentDrawPoints中，只需要取最后一个点即可。
    if (self.realDrawPoints.count > 1) {
        if (self.brushType == UkeDrawingBrushTypeLine ||
            self.brushType == UkeDrawingBrushTypeEllipse ||
            self.brushType == UkeDrawingBrushTypeRectangle||
            self.brushType == UkeDrawingBrushTypeEraserRectangle ||
            self.brushType == UkeDrawingBrushTypeLineArrow ||
            self.brushType == UkeDrawingBrushTypeStar) {
            
            self.realDrawPoints = [NSMutableArray arrayWithObject:self.realDrawPoints.lastObject];
        }
    }
    
    // 回调
    __weak typeof(self)weakSelf = self;
    if (completionHandler) {
        completionHandler(weakSelf);
    }
    
    // 如果是结束路径
    if (self.currentDrawingState&UkeDrawingStateEnd || forcedEnd) {
        self.identifier = nil;
        self.editInfo = nil;
        self.currentActionId = nil;
        self.currentBrushType = nil;
        self.lineWidth = 0;
        self.color = nil;
        self.isFillPath = NO;
        self.isNormalShape = NO;
        self.startPoint = nil;
    }
    
    self.currentDrawingState = UkeDrawingStateUnknown;
    self.realDrawPoints = [NSMutableArray array];
    self.forceEndPreviousPath = NO;
    self.text = nil;
}

- (void)resetData {
    
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
    return self.currentBrushType.brushType_int;
}

- (UkeDrawingState)drawingState {
    return self.currentDrawingState;
}

@end
