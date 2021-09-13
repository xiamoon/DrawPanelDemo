//
//  UkePaintingView.h
//  DrawPanel
//
//  Created by liqian on 2019/1/31.
//  Copyright © 2019 liqian. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UkeDrawingConstants.h"
#import "UkeGraphicEditInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface UkePaintingView : UIView

//! 当前绘画内容
@property (nonatomic, strong) UIImage *currentContents;

/// 画图形
- (void)drawWithMode:(UkeDrawingBrushType)drawingMode
        drawingState:(UkeDrawingState)state
          startPoint:(NSValue *)startPoint
         otherPoints:(NSArray<NSValue *> *)points
               width:(CGFloat)width
               color:(UIColor *)color
          isFillPath:(BOOL)isFillPath
       isNormalShape:(BOOL)isNormalShape
            forceEnd:(BOOL)forceEnd
          identifier:(NSString *)identifier
         targetLayer:(nullable CALayer *)targetLayer
          showVertex:(BOOL)showVertex;

/// 画文字
- (void)drawTextWithText:(NSString *)text
              startPoint:(NSValue *)startPoint
                fontSize:(CGFloat)fontSize
                   color:(UIColor *)color
              identifier:(nonnull NSString *)identifier
             targetLayer:(nullable CALayer *)targetLayer
               transform:(CGPoint)transform;

/// 编辑图形
- (void)editWithEditInfo:(UkeGraphicEditInfo *)editInfo
              identifier:(NSString *)identifier;

/// 删除图形
- (void)deleteWithIdentifiers:(NSSet *)identifiers;

/// 删除整页
- (void)deleteCurrentPage;

@end

NS_ASSUME_NONNULL_END
