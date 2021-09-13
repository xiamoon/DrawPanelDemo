//
//  UkeEraseMaskLayer.m
//  ZMUke
//
//  Created by liqian on 2020/4/13.
//  Copyright © 2020 zmlearn. All rights reserved.
//

#import "UkeEraseMaskLayer.h"
#import <UIKit/UIKit.h>

typedef struct {
    CGPathRef strokePath;
    CGFloat strokeWidth;
} StrokePathInfo;

@interface UkeEraseMaskLayer ()
@property (nonatomic, assign) CGMutablePathRef eraseFillPath;
//@property (nonatomic, assign) CGMutablePathRef eraseStrokePath;
@property (nonatomic, strong) NSMutableSet<NSValue *> *strokePaths;
@end

@implementation UkeEraseMaskLayer

/// 清除指定path区域的内容
void CGContextClearPathArea(CGContextRef ctx, CGPathRef path, CGPathDrawingMode mode, CGFloat strokeWidth) {

    CGContextAddPath(ctx, path);
    if (mode == kCGPathStroke) {
//        CGContextSaveGState(ctx);
        CGContextSetLineWidth(ctx, strokeWidth);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        CGContextSetLineJoin(ctx, kCGLineJoinRound);
//        CGContextRestoreGState(ctx);
    }
    CGContextSetBlendMode(ctx, kCGBlendModeClear);

    CGContextDrawPath(ctx, mode);
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.strokePaths = [NSMutableSet set];
    }
    return self;
}

- (void)drawInContext:(CGContextRef)ctx {
    
    if (CGPathIsEmpty(self.eraseFillPath) && self.strokePaths.count==0) return;
    
    CGContextSetFillColorWithColor(ctx, [UIColor blackColor].CGColor);
    CGContextFillRect(ctx, self.bounds);
    
    if (!CGPathIsEmpty(self.eraseFillPath)) {
        CGContextClearPathArea(ctx, self.eraseFillPath, kCGPathFill, 0);
    }
    
    if (self.strokePaths.count) {
        [self.strokePaths enumerateObjectsUsingBlock:^(NSValue * _Nonnull obj, BOOL * _Nonnull stop) {
            StrokePathInfo info;
            if (@available(iOS 11.0, *)) {
                [obj getValue:&info size:sizeof(StrokePathInfo)];
            } else {
                [obj getValue:&info];
            }
            CGContextClearPathArea(ctx, info.strokePath, kCGPathStroke, info.strokeWidth);
        }];
    }
    
//    if (!CGPathIsEmpty(self.eraseStrokePath)) {
//        CGContextClearPath(ctx, self.eraseStrokePath, kCGPathStroke, 50);
//    }
}

- (void)appendErasePath:(CGPathRef)erasePath drawingMode:(CGPathDrawingMode)mode width:(CGFloat)width {
    
    if (CGPathIsEmpty(erasePath)) return;
    
    if (mode == kCGPathFill) {
        if (self.eraseFillPath == nil) {
            //TODO: 是否要release?
            self.eraseFillPath = CGPathCreateMutableCopy(erasePath);
        } else {
            CGPathAddPath(self.eraseFillPath, NULL, erasePath);
        }
    } else if (mode == kCGPathStroke) {
        //TODO: 是否要release?
        StrokePathInfo info = {CGPathCreateCopy(erasePath), width};

        [self.strokePaths addObject:[NSValue valueWithBytes:&info objCType:@encode(StrokePathInfo)]];
        
//        erasePath = CGPathCreateCopyByStrokingPath(erasePath, NULL, width, kCGLineCapRound, kCGLineJoinRound, 0);
//        if (self.eraseStrokePath == nil) {
//            self.eraseStrokePath = CGPathCreateMutableCopy(erasePath);
//        } else {
//            CGPathAddPath(self.eraseStrokePath, NULL, erasePath);
//        }
    }
    
    [self setNeedsDisplay];
}

- (void)clearUpResource {
    CGPathRelease(self.eraseFillPath);
    
    [self.strokePaths enumerateObjectsUsingBlock:^(NSValue * _Nonnull obj, BOOL * _Nonnull stop) {
        StrokePathInfo info;
        if (@available(iOS 11.0, *)) {
            [obj getValue:&info size:sizeof(StrokePathInfo)];
        } else {
            [obj getValue:&info];
        }
        CGPathRelease(info.strokePath);
    }];
}

- (void)dealloc {
    NSLog(@"UkeEraseMaskLayer dealloc");
}

@end
