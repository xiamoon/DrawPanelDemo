//
//  UkeDrawingPointsParser.h
//  ZMUke
//
//  Created by liqian on 2019/6/24.
//  Copyright © 2019 zmlearn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "UkeDrawingConstants.h"

NS_ASSUME_NONNULL_BEGIN

@interface UkeDrawingPointsParser : NSObject

// x坐标缩放比
@property (nonatomic, assign) CGFloat scaleX;

// y坐标缩放比
@property (nonatomic, assign) CGFloat scaleY;

// 画笔类型
- (UkeDrawingBrushType)brushType;

// 绘画状态
- (UkeDrawingState)drawingState;

// 开始数据点
- (NSValue *)startPoint;

// 真正用于绘画的坐标点数组
- (NSMutableArray<NSValue *> *)realDrawPoints;

// 是否填充，默认NO。只有圆、框、三角形、五角星有填充与否的属性
- (BOOL)isFillPath;

// 是否是正圆或正多边形，默认NO。只有圆、框、三角形、有是否为正的属性
- (BOOL)isNormalShape;

// 线宽
- (CGFloat)lineWidth;

// 线的颜色
- (nullable UIColor *)color;

// 绘画文字
- (nullable NSString *)text;

// 是否强制结束。如：当第二笔数据过来时，如果前一笔还没结束，则强制结束前一笔路径。默认NO
- (BOOL)forceEndPreviousPath;


// 解析点
- (void)parseWithPoints:(NSArray<NSArray *> *)points
             completion:(void(^)(UkeDrawingPointsParser *parser))completionHandler;

@end

NS_ASSUME_NONNULL_END
