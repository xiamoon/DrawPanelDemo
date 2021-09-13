//
//  UkeEraseMaskLayer.h
//  ZMUke
//
//  Created by liqian on 2020/4/13.
//  Copyright © 2020 zmlearn. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface UkeEraseMaskLayer : CALayer

- (void)appendErasePath:(CGPathRef)erasePath drawingMode:(CGPathDrawingMode)mode width:(CGFloat)width;

- (void)clearUpResource;

@end

NS_ASSUME_NONNULL_END
