//
//  UkeDrawingCanvas.h
//  DrawPanel
//
//  Created by liqian on 2019/1/26.
//  Copyright © 2019 liqian. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UkeDrawingConstants.h"

NS_ASSUME_NONNULL_BEGIN

@interface UkeDrawingCanvas : UIView

// 可视大小，只用于计算点的比例
@property (nonatomic, assign) CGSize visualSize;

#pragma mark - 数据点驱动绘画
//! 服务器数据点驱动绘画
- (void)drawWithPoints:(NSArray<NSArray *> *)points;


- (void)authorizeDrawing;
- (void)unAuthorizeDrawing;
- (void)chooseBrush;
- (void)chooseEraser;
- (void)setBrushWidth:(CGFloat)brushWidth;
- (void)setBrushColor:(UIColor *)brushColor;
- (void)setEraserWidth:(CGFloat)eraserWidth;

@end

NS_ASSUME_NONNULL_END
