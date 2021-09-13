//
//  UkePaintingView.h
//  DrawPanel
//
//  Created by liqian on 2019/1/31.
//  Copyright © 2019 liqian. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UkeDrawingConstants.h"

NS_ASSUME_NONNULL_BEGIN

@interface UkePaintingViewRootLayer : CALayer
@end

@interface UkePaintingView : UIView

//! 当前绘画内容
@property (nonatomic, strong) UIImage *currentContents;

//! 服务端数据驱动绘制时调用这个接口
- (void)drawWithMode:(UkeDrawingBrushType)drawingMode
        drawingState:(UkeDrawingState)state
          startPoint:(NSValue *)startPoint
         otherPoints:(NSArray<NSValue *> *)points
               width:(CGFloat)width
               color:(UIColor *)color
          isFillPath:(BOOL)isFillPath
       isNormalShape:(BOOL)isNormalShape
            forceEnd:(BOOL)forceEnd;

// 画文字
- (void)drawTextWithText:(NSString *)text
              startPoint:(NSValue *)startPoint
                fontSize:(CGFloat)fontSize
                   color:(UIColor *)color;

@end

NS_ASSUME_NONNULL_END
