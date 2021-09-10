//
//  UkePaintingView.m
//  DrawPanel
//
//  Created by liqian on 2019/1/31.
//  Copyright © 2019 liqian. All rights reserved.
//

#import "UkePaintingView.h"

@implementation UkePaintingViewRootLayer
- (instancetype)init {
    self = [super init];
    if (self) {
        self.contentsScale = [UIScreen mainScreen].scale;
    }
    return self;
}

- (void)dealloc {
    NSLog(@"%s", __func__);
}

@end

@interface UkePaintingView ()
@property (nonatomic, assign) UkeDrawingBrushType currentDrawingMode;
@property (nonatomic, assign) CGPoint startPoint;
@property (nonatomic, strong) UIBezierPath *currentPath;
@property (nonatomic, strong) CAShapeLayer *currentLayer;
// 激光笔
@property (nonatomic, strong) CALayer *laserPenLayer;
@end

@implementation UkePaintingView

- (instancetype)init {
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.layer.contentsScale = [UIScreen mainScreen].scale;
        
        _laserPenLayer = [CALayer layer];
        _laserPenLayer.backgroundColor = UkeColorHex(0xFF6161).CGColor;
        _laserPenLayer.bounds = CGRectMake(0, 0, 8, 8);
        _laserPenLayer.cornerRadius = 4.0;
        _laserPenLayer.shadowOpacity = 1.0;
        _laserPenLayer.shadowColor = UkeColorHex(0xFF9898).CGColor;
        _laserPenLayer.shadowOffset = CGSizeMake(0, 0);
        _laserPenLayer.hidden = YES;
        [self.layer addSublayer:_laserPenLayer];
    }
    return self;
}

+ (Class)layerClass {
    return [UkePaintingViewRootLayer class];
}

- (void)dealloc {
    [self.layer.sublayers.copy makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
    self.laserPenLayer = nil;
    self.currentPath = nil;
    self.currentLayer = nil;
    
    NSLog(@"paintingView销毁");
}

- (UIImage *)currentContents {
    UIGraphicsBeginImageContextWithOptions(self.frame.size, NO, [UIScreen mainScreen].scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [self.layer renderInContext:context];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)setCurrentContents:(UIImage *)currentContents {
    self.layer.contents = (id)currentContents.CGImage;
}

//! 角度转弧度
static double radianFromDegree(double degree) {
    return (degree/180.0*M_PI);
}

//! 弧度转角度
static double degreeFromRadian(double radian) {
    return (radian*180.0/M_PI);
}

- (void)drawWithMode:(UkeDrawingBrushType)drawingMode
        drawingState:(UkeDrawingState)state
          startPoint:(NSValue *)startPoint
         otherPoints:(NSArray<NSValue *> *)points
               width:(CGFloat)width
               color:(UIColor *)color
          isFillPath:(BOOL)isFillPath
       isNormalShape:(BOOL)isNormalShape
            forceEnd:(BOOL)forceEnd {
    
    if (state&UkeDrawingStateStart) {
        _currentDrawingMode = drawingMode;
        _startPoint = startPoint.CGPointValue;
        _currentLayer = nil;
        _currentPath = nil;
    }
    
    if ((state&UkeDrawingStateStart) && _currentDrawingMode != UkeDrawingBrushTypeEraser) {
        [self createLayerWithWidth:width color:color isFillPath:isFillPath isEraserRectangle:(_currentDrawingMode == UkeDrawingBrushTypeEraserRectangle)];
    }
    
    if (_currentDrawingMode == UkeDrawingBrushTypeBrush ||
        _currentDrawingMode == UkeDrawingBrushTypePressurePen) { // 线
        _currentLayer.lineJoin = @"round";
        _currentLayer.lineCap = @"round";
        if (state&UkeDrawingStateStart) {
            _currentPath = [UIBezierPath bezierPath];
            _currentPath.lineJoinStyle = kCGLineJoinRound;
            _currentPath.lineCapStyle = kCGLineCapRound;
            [_currentPath moveToPoint:_startPoint];
            
            [self showLaserPenLayerWithPoint:_startPoint];
        }
        
        if (points.count) {
            for (int i = 0; i < points.count; i ++) {
                CGPoint currentPoint = [points[i] CGPointValue];
                [_currentPath addLineToPoint:currentPoint];
                
                [self showLaserPenLayerWithPoint:currentPoint];
            }
        }
    }else if (_currentDrawingMode == UkeDrawingBrushTypeLine) { // 线段
        if (points.count) {
            for (int i = 0; i < points.count; i ++) {
                CGPoint currentPoint = [points[i] CGPointValue];
                _currentPath = [UIBezierPath bezierPath];
                [_currentPath moveToPoint:_startPoint];
                [_currentPath addLineToPoint:currentPoint];
            }
        }
    }
    else if (_currentDrawingMode == UkeDrawingBrushTypeEllipse) { // 圆
        if (points.count) {
            for (int i = 0; i < points.count; i ++) {
                CGPoint currentPoint = [points[i] CGPointValue];
                
                if (isNormalShape) { // 正圆
                    // 直径
                    CGFloat diameter = MIN(fabs(currentPoint.x-_startPoint.x), fabs(currentPoint.y-_startPoint.y));
                    CGFloat widthAndHeight = (currentPoint.x-_startPoint.x)>0?diameter:(-diameter);
                    _currentPath = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(_startPoint.x, _startPoint.y, widthAndHeight, widthAndHeight)];
                }else { // 椭圆
                    _currentPath = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(_startPoint.x, _startPoint.y, currentPoint.x-_startPoint.x, currentPoint.y-_startPoint.y)];
                }
            }
        }
    }else if (_currentDrawingMode == UkeDrawingBrushTypeRectangle) { // 矩形框
        if (points.count) {
            for (int i = 0; i < points.count; i ++) {
                CGPoint currentPoint = [points[i] CGPointValue];
                
                if (isNormalShape) { // 正方形
                    // 直径
                    CGFloat diameter = fabs(currentPoint.x-_startPoint.x);
                    CGFloat widthAndHeight = (currentPoint.x-_startPoint.x)>0?diameter:(-diameter);
                    _currentPath = [UIBezierPath bezierPathWithRect:CGRectMake(_startPoint.x, _startPoint.y, widthAndHeight, widthAndHeight)];
                }else { // 矩形
                    _currentPath = [UIBezierPath bezierPathWithRect:CGRectMake(_startPoint.x, _startPoint.y, currentPoint.x-_startPoint.x, currentPoint.y-_startPoint.y)];
                }
            }
        }
    }
    else if (_currentDrawingMode == UkeDrawingBrushTypeTriangle) { // 三角形
        if (points.count == 2) {
            CGPoint point1 = [points[0] CGPointValue];
            CGPoint point2 = [points[1] CGPointValue];
            if (isNormalShape) {
                // 中垂线长度
                CGFloat m = fabs(point1.y-_startPoint.y);
                CGFloat l = m*tan(radianFromDegree(30.0));
                point1 = CGPointMake(_startPoint.x-l, point1.y);
                point2 = CGPointMake(_startPoint.x+l, point2.y);
            }
            _currentPath = [UIBezierPath bezierPath];
            [_currentPath moveToPoint:CGPointMake(_startPoint.x, _startPoint.y)];
            [_currentPath addLineToPoint:CGPointMake(point1.x, point1.y)];
            [_currentPath addLineToPoint:CGPointMake(point2.x, point2.y)];
            [_currentPath closePath];
        }
    }else if (_currentDrawingMode == UkeDrawingBrushTypeStar) { // 五角星
        [self drawStarWithStartPoint:_startPoint otherPoints:points];
    }else if (_currentDrawingMode == UkeDrawingBrushTypeLineArrow) { // 箭头
        [self drawLineArrowWithStartPoint:_startPoint otherPoints:points width:width color:color];
    }else if (_currentDrawingMode == UkeDrawingBrushTypeEraser) { // 橡皮擦
        if (state&UkeDrawingStateStart) {
            _currentPath = [UIBezierPath bezierPath];
            [_currentPath moveToPoint:_startPoint];
        }
        
        if (points.count) {
            for (int i = 0; i < points.count; i ++) {
                CGPoint currentPoint = [points[i] CGPointValue];
                [_currentPath addLineToPoint:currentPoint];
            }
            
            [self.layer.sublayers.copy enumerateObjectsUsingBlock:^(__kindof CALayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                CGFloat x = obj.position.x;
                CGFloat y = obj.position.y;
                CGFloat w = obj.bounds.size.width;
                CGFloat h = obj.bounds.size.height;
                if (x == INFINITY || y == INFINITY || w == INFINITY || h == INFINITY) {
                    [obj removeFromSuperlayer];
                }
            }];
            
            // 把当前layer的所有内容生成一张图片
            [self hideLaserPenLayer];
            UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, [UIScreen mainScreen].scale);
            CGContextRef context = UIGraphicsGetCurrentContext();
            [self.layer renderInContext:context];
            
            // 移除当前layer上的所有内容，激光笔除外
            [self.layer.sublayers.copy enumerateObjectsUsingBlock:^(__kindof CALayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (obj != self.laserPenLayer) {
                    [obj removeFromSuperlayer];
                }
            }];

            // 再把图片设置为当前layer的内容
            CGContextSetLineWidth(context, width);
            CGContextSetBlendMode(context, kCGBlendModeClear);
            CGContextAddPath(context, _currentPath.CGPath);
            CGContextDrawPath(context, kCGPathStroke);
            UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
            self.layer.contents = (id)image.CGImage;
            UIGraphicsEndImageContext();
        }
    }else if (_currentDrawingMode == UkeDrawingBrushTypeEraserRectangle) { // 框选删除
        if (points.count) {
            for (int i = 0; i < points.count; i ++) {
                CGPoint currentPoint = [points[i] CGPointValue];
                _currentPath = [UIBezierPath bezierPathWithRect:CGRectMake(_startPoint.x, _startPoint.y, currentPoint.x-_startPoint.x, currentPoint.y-_startPoint.y)];
            }
        }
        
        if (state&UkeDrawingStateEnd || forceEnd) {
            [_currentLayer removeFromSuperlayer];
            _currentLayer = nil;
            
            [self.layer.sublayers.copy enumerateObjectsUsingBlock:^(__kindof CALayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                CGFloat x = obj.position.x;
                CGFloat y = obj.position.y;
                CGFloat w = obj.bounds.size.width;
                CGFloat h = obj.bounds.size.height;
                if (x == INFINITY || y == INFINITY || w == INFINITY || h == INFINITY) {
                    [obj removeFromSuperlayer];
                }
            }];
            
            // 把当前layer的所有内容生成一张图片
            [self hideLaserPenLayer];
            UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, [UIScreen mainScreen].scale);
            CGContextRef context = UIGraphicsGetCurrentContext();
            [self.layer renderInContext:context];
            
            // 移除当前layer上的所有内容，激光笔除外
            [self.layer.sublayers.copy enumerateObjectsUsingBlock:^(__kindof CALayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (obj != self.laserPenLayer) {
                    [obj removeFromSuperlayer];
                }
            }];
            
            // 再把图片设置为当前layer的内容
            CGContextSetBlendMode(context, kCGBlendModeClear);
            CGContextAddPath(context, _currentPath.CGPath);
            CGContextDrawPath(context, kCGPathFill);
            UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
            self.layer.contents = (id)image.CGImage;
            UIGraphicsEndImageContext();
        }
    }
    
    
    if (_currentDrawingMode != UkeDrawingBrushTypeEraser && _currentPath) {
        _currentLayer.path = _currentPath.CGPath;
    }
    
    if (state&UkeDrawingStateEnd || forceEnd) {
        [self hideLaserPenLayer];
        _currentLayer = nil;
        _currentPath = nil;
    }
}

// 画五角星
- (void)drawStarWithStartPoint:(CGPoint)startPoint
                   otherPoints:(NSArray<NSValue *> *)points {
    if (points.count == 0) return;
    
    // 设O为圆心，A（上顶点）、B、C、D、E为外点(顺时针方向)，F（右上角内点）、G、H、I、J为内点（顺时针方向）。每个外角为36度
    // 大圆圆心
    CGPoint O = startPoint;
    
    for (NSValue *value in points) {
        CGPoint currentPoint = value.CGPointValue;
        
        
        // 大圆半径
        CGFloat radius_max = fabs(2*(currentPoint.x-O.x));
        
        CGPoint A = CGPointMake(O.x, O.y-radius_max);
        CGPoint B = CGPointMake(O.x+radius_max*cos(radianFromDegree(18.0)), O.y-radius_max*sin(radianFromDegree(18.0)));
        CGPoint C = CGPointMake(O.x+radius_max*sin(radianFromDegree(36.0)), O.y+radius_max*cos(radianFromDegree(36.0)));
        CGPoint D = CGPointMake(O.x-radius_max*sin(radianFromDegree(36.0)), C.y);
        CGPoint E = CGPointMake(O.x-radius_max*cos(radianFromDegree(18.0)), B.y);
        
        // 小圆半径
        CGFloat radius_min = radius_max*sin(radianFromDegree(18.0))/cos(radianFromDegree(36.0));
        
        CGPoint F = CGPointMake(O.x+radius_max*sin(radianFromDegree(18.0))*tan(radianFromDegree(36.0)), B.y);
        CGPoint G = CGPointMake(O.x+radius_min*cos(radianFromDegree(18.0)), O.y+radius_min*sin(radianFromDegree(18.0)));
        CGPoint H = CGPointMake(O.x, O.y+radius_min);
        CGPoint I = CGPointMake(O.x-radius_min*cos(radianFromDegree(18.0)), G.y);
        CGPoint J = CGPointMake(O.x-radius_max*sin(radianFromDegree(18.0))*tan(radianFromDegree(36.0)), F.y);
        
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:A];
        [path addLineToPoint:F];
        [path addLineToPoint:B];
        [path addLineToPoint:G];
        [path addLineToPoint:C];
        [path addLineToPoint:H];
        [path addLineToPoint:D];
        [path addLineToPoint:I];
        [path addLineToPoint:E];
        [path addLineToPoint:J];
        [path addLineToPoint:A];
        
        _currentPath = path;
    }
}

// 画箭头
- (void)drawLineArrowWithStartPoint:(CGPoint)startPoint
                        otherPoints:(NSArray<NSValue *> *)points
                              width:(CGFloat)width
                              color:(UIColor *)color {
    if (points.count != 1) {
        return;
    }
    
    while (_currentLayer.sublayers.count) {
        [_currentLayer.sublayers.lastObject removeFromSuperlayer];
    }
    
    CGPoint endPoint = [points.lastObject CGPointValue];
    
    CGFloat a = endPoint.x-startPoint.x;
    CGFloat b = startPoint.y-endPoint.y;
    CGFloat c = sqrt(a*a+b*b);
    
    CGFloat degreeB = 0;
    if (c != 0) {
        degreeB = degreeFromRadian(asin(fabs(b)/c));
    }
    
    CGFloat degreeRotate = 0;
    if (a>0 && b>=0) { // 第一象限
        degreeRotate = 360.0-degreeB;
    }else if (a<=0 && b>=0) { // 第二象限
        degreeRotate = 180.0+degreeB;
    }else if (a<=0 && b<0) { // 第三象限
        degreeRotate = 180.0-degreeB;
    }else if (a>0 && b<=0) {// 第四象限
        degreeRotate = degreeB;
    }
    
    // 箭头夹角（小于90度）
    CGFloat arrowDegree = 60.0;
    // 一半箭头的夹角
    CGFloat singleArrowDegree = arrowDegree*0.5;
    // 线宽
    CGFloat lineWidth = width;
    // n决定箭头两边的长短。n越大，箭头两边越长，反之，越短
    CGFloat n = lineWidth*0.8;
    // 线加上箭头总体宽度，即下面lineLayer的宽度
    CGFloat lineLayerWidth = 2*n+2*lineWidth*cos(radianFromDegree(singleArrowDegree)) +lineWidth;
    
    // 线段
    CAShapeLayer *lineLayer = [[CAShapeLayer alloc] init];
    lineLayer.anchorPoint = CGPointMake(0, 0.5);
    lineLayer.position = startPoint;
    lineLayer.backgroundColor = [UIColor clearColor].CGColor;
    lineLayer.lineWidth = lineWidth;
    lineLayer.fillColor = [UIColor clearColor].CGColor;
    lineLayer.strokeColor = color.CGColor;
    [_currentLayer addSublayer:lineLayer];
    
    UIBezierPath *linePath = [UIBezierPath bezierPath];
    [linePath moveToPoint:CGPointMake(0, lineLayerWidth*0.5)];
    [linePath addLineToPoint:CGPointMake(c-0.5*lineWidth/sin(radianFromDegree(singleArrowDegree)), lineLayerWidth*0.5)];
    lineLayer.path = linePath.CGPath;
    
    // 箭头
    CAShapeLayer *arrowLayer = [[CAShapeLayer alloc] init];
    arrowLayer.bounds = CGRectMake(0, 0, lineLayerWidth, lineLayerWidth);
    arrowLayer.position = CGPointMake(c-lineLayerWidth*0.5, lineLayerWidth*0.5);
    arrowLayer.backgroundColor = [UIColor clearColor].CGColor;
    arrowLayer.lineWidth = lineWidth;
    arrowLayer.fillColor = color.CGColor;
    arrowLayer.strokeColor = color.CGColor;
    [lineLayer addSublayer:arrowLayer];
    
    UIBezierPath *arrowPath = [UIBezierPath bezierPath];
    [arrowPath moveToPoint:CGPointMake(0.5*lineWidth*sin(radianFromDegree(singleArrowDegree)), 0.5*lineWidth*cos(radianFromDegree(singleArrowDegree)))];
    [arrowPath addLineToPoint:CGPointMake(lineLayerWidth-0.5*lineWidth/sin(radianFromDegree(singleArrowDegree)), lineLayerWidth*0.5)];
    [arrowPath addLineToPoint:CGPointMake(0.5*lineWidth*sin(radianFromDegree(singleArrowDegree)), lineLayerWidth-0.5*lineWidth*cos(radianFromDegree(singleArrowDegree)))];
    [arrowPath closePath];
    arrowLayer.path = arrowPath.CGPath;
    
    // 整体拉长和旋转
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    lineLayer.bounds = CGRectMake(0, 0, c, lineLayerWidth);
    [lineLayer setAffineTransform:CGAffineTransformMakeRotation(degreeRotate/180.0*M_PI)];
    [CATransaction commit];
}

// 画文字
- (void)drawTextWithText:(NSString *)text
              startPoint:(NSValue *)startPoint
                fontSize:(CGFloat)fontSize
                   color:(UIColor *)color {
    if (![text isKindOfClass:[NSString class]] || !text.length) {
        return;
    }
    CGPoint point = startPoint.CGPointValue;
    
    CALayer *layer = [[CALayer alloc] init];
    layer.contentsScale = [UIScreen mainScreen].scale;
    layer.backgroundColor = [UIColor clearColor].CGColor;
    [self.layer addSublayer:layer];

    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineSpacing = 2.0;
    style.maximumLineHeight = fontSize;
    style.minimumLineHeight = fontSize;
    style.lineBreakMode = NSLineBreakByCharWrapping;
    
    NSMutableAttributedString *attri = [[NSMutableAttributedString alloc] initWithString:text];
    [attri addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, text.length)];
    [attri addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:fontSize weight:UIFontWeightRegular] range:NSMakeRange(0, text.length)];
    [attri addAttribute:NSParagraphStyleAttributeName value:style range:NSMakeRange(0, text.length)];
    [attri addAttribute:NSKernAttributeName value:@(-0.24) range:NSMakeRange(0, text.length)];

    CGSize textSize = [attri boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin context:NULL].size;
    CGRect layerFrame = CGRectMake(point.x, point.y, textSize.width, textSize.height);
    layer.frame = layerFrame;

    UIGraphicsBeginImageContextWithOptions(layer.bounds.size, NO, [UIScreen mainScreen].scale);
    [attri drawInRect:layer.bounds];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    layer.contents = (id)image.CGImage;
}

- (void)createLayerWithWidth:(CGFloat)width
                       color:(UIColor *)color
                  isFillPath:(BOOL)isFillPath
           isEraserRectangle:(BOOL)isEraserRectangle {
    CAShapeLayer *layer = [[CAShapeLayer alloc] init];
    layer.contentsScale = [UIScreen mainScreen].scale;
    layer.backgroundColor = [UIColor clearColor].CGColor;
    if (isEraserRectangle) {
        layer.fillColor = [[UIColor redColor] colorWithAlphaComponent:0.4].CGColor;
        layer.strokeColor = [UIColor clearColor].CGColor;
    }else {
        layer.strokeColor = color.CGColor;
        if (isFillPath) {
            layer.fillColor = color.CGColor;
        }else {
            layer.fillColor = [UIColor clearColor].CGColor;
        }
    }
    layer.frame = self.frame;
    layer.lineWidth = width;
    [self.layer addSublayer:layer];
    
    _currentLayer = layer;
}

- (void)showLaserPenLayerWithPoint:(CGPoint)point {
    _laserPenLayer.hidden = NO;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _laserPenLayer.position = point;
    [CATransaction commit];
}

- (void)hideLaserPenLayer {
    _laserPenLayer.hidden = YES;
}

@end
