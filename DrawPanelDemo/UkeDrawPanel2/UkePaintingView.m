//
//  UkePaintingView.m
//  DrawPanel
//
//  Created by liqian on 2019/1/31.
//  Copyright © 2019 liqian. All rights reserved.
//

#import "UkePaintingView.h"
#import "UkeEraseMaskLayer.h"

@interface UkePaintingViewRootLayer : CALayer
@end

@implementation UkePaintingViewRootLayer
- (instancetype)init {
    self = [super init];
    if (self) {
        self.contentsScale = [UIScreen mainScreen].scale;
    }
    return self;
}
@end


@interface UkeDrawingItemLayer : CAShapeLayer
@property (nonatomic, copy) NSString *identifier; //!< 每个形状的对应一个id，通过id可以编辑该形状
@property (nonatomic, assign) UkeDrawingBrushType type;

@property (nonatomic, copy, nullable) NSString *originalText; // 原始文字
@property (nonatomic, strong) NSMutableArray<NSValue *> *originalPonits; // 原始数据点

@property (nonatomic, assign) CGPoint currentTranslation;
@property (nonatomic, assign) CGPoint currentScale;
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, assign) BOOL isFillPath;
@property (nonatomic, assign) BOOL isNormalShape;

@property (nonatomic, assign) BOOL showVertex; // 是否显示顶点。先写成属性，后期再整理

// 针对坐标系，后期再改动
@property (nonatomic, assign) CGPoint currentCoorSysXYTranslation;

@property (nonatomic, strong, nullable) NSArray<NSString *> *currentVertexStringList;
@end

@implementation UkeDrawingItemLayer
- (NSMutableArray<NSValue *> *)originalPonits {
    if (!_originalPonits) {
        _originalPonits = [NSMutableArray array];
    }
    return _originalPonits;;
}

- (CGPoint)currentScale {
    if (CGPointEqualToPoint(_currentScale, CGPointZero)) {
        return CGPointMake(1.f, 1.f);
    }
    return _currentScale;
}

- (void)dealloc {
    UkeEraseMaskLayer *eraseLayer = (UkeEraseMaskLayer *)self.mask;
    if ([eraseLayer isKindOfClass:[UkeEraseMaskLayer class]]) {
        [eraseLayer clearUpResource];
    }
    
//    NSLog(@"UkeDrawingItemLayer dealloc");
}

@end

@interface UkePaintingView ()
@property (nonatomic, assign) UkeDrawingBrushType currentDrawingMode;
@property (nonatomic, assign) CGPoint startPoint;
@property (nonatomic, strong) UIBezierPath *currentPath;
@property (nonatomic, strong) UkeDrawingItemLayer *currentLayer;
// 激光笔
@property (nonatomic, strong) CALayer *laserPenLayer;

@end

@implementation UkePaintingView {
    NSInteger currentVertexCharIndex; /// 顶点字母下标
    NSInteger currentVertexNum; /// 顶点数字
}

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
        
        currentVertexCharIndex = -1;
        currentVertexNum = 0;
    }
    return self;
}

+ (Class)layerClass {
    return [UkePaintingViewRootLayer class];
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
            forceEnd:(BOOL)forceEnd
          identifier:(nonnull NSString *)identifier
         targetLayer:(nullable CALayer *)targetLayer
          showVertex:(BOOL)showVertex {
    
    if (startPoint == nil) {
        return;
    }
    
    if (state&UkeDrawingStateStart) {
        _currentDrawingMode = drawingMode;
        _startPoint = startPoint.CGPointValue;
        _currentLayer = nil;
        _currentPath = nil;
    }
    
    if (targetLayer) {
        // 编辑的时候需要重绘，所以这里要先清除子图层
        while (targetLayer.sublayers.lastObject) {
            [targetLayer.sublayers.lastObject removeFromSuperlayer];
        }
        _currentLayer = (UkeDrawingItemLayer *)targetLayer;
    } else {
        if ((state&UkeDrawingStateStart) && _currentDrawingMode != UkeDrawingBrushTypeEraser) {
            [self createLayerWithWidth:width color:color isFillPath:isFillPath isEraserRectangle:(_currentDrawingMode == UkeDrawingBrushTypeEraserRectangle) identifier:identifier];
            [_currentLayer.originalPonits removeAllObjects];
            [_currentLayer.originalPonits addObject:startPoint];
            _currentLayer.showVertex = showVertex;
            _currentLayer.type = drawingMode;
            _currentLayer.width = width;
            _currentLayer.color = color;
            _currentLayer.isFillPath = isFillPath;
            _currentLayer.isNormalShape = isNormalShape;
        }
    }
    
    if (!targetLayer && [identifier isEqualToString:_currentLayer.identifier]) {
        if (state&UkeDrawingStateDrawing || state&UkeDrawingStateEnd) {
            [_currentLayer.originalPonits addObjectsFromArray:points];
        }
    }
    
    if (_currentDrawingMode == UkeDrawingBrushTypeBrush ||
        _currentDrawingMode == UkeDrawingBrushTypePressurePen) { // 线、按压笔
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
    }
    else if (_currentDrawingMode == UkeDrawingBrushTypeLine) { // 线段
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
    }
    else if (_currentDrawingMode == UkeDrawingBrushTypeRectangle) { // 矩形框
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
        CAShapeLayer *lineArrowLayer = [self drawLineArrowWithStartPoint:_startPoint otherPoints:points width:width color:color scale:_currentLayer.currentScale.x bigArrow:NO];
        lineArrowLayer.frame = _currentLayer.bounds;
        [_currentLayer addSublayer:lineArrowLayer];
    }
    else if (_currentDrawingMode == UkeDrawingBrushTypePolygon_edit) { // 可编辑多边形
        _currentLayer.lineJoin = @"round";
        _currentLayer.lineCap = @"round";
        if (state&UkeDrawingStateStart) {
            _currentPath = [UIBezierPath bezierPath];
            _currentPath.lineJoinStyle = kCGLineJoinRound;
            _currentPath.lineCapStyle = kCGLineCapRound;
            [_currentPath moveToPoint:_startPoint];
        }
        
        if (points.count) {
            for (int i = 0; i < points.count; i ++) {
                CGPoint currentPoint = [points[i] CGPointValue];
                [_currentPath addLineToPoint:currentPoint];
            }
            [_currentPath closePath];
        }
        
        _currentLayer.fillColor = [color colorWithAlphaComponent:0.08].CGColor;
        
        NSMutableArray *vertexArray = [NSMutableArray array];
        [vertexArray addObject:startPoint];
        [vertexArray addObjectsFromArray:points];
        
        [self drawVertexForGraphic:_currentLayer withPoints:vertexArray color:color scale:_currentLayer.currentScale.x];
    }
    else if (_currentDrawingMode == UkeDrawingBrushTypeCircle_edit) { // 可编辑同心圆
        if (points.count) {
            for (int i = 0; i < points.count; i ++) {
                CGPoint currentPoint = [points[i] CGPointValue];
                
                CGFloat x = fabs(currentPoint.x-_startPoint.x);
                CGFloat y = fabs(currentPoint.y-_startPoint.y);
                CGFloat radius = sqrt(x*x + y*y);
                
                _currentPath = [UIBezierPath bezierPathWithArcCenter:_startPoint radius:radius startAngle:0 endAngle:M_PI*2 clockwise:YES];
            }
            
            _currentLayer.fillColor = [color colorWithAlphaComponent:0.08].CGColor;
            
            NSMutableArray *vertexArray = [NSMutableArray array];
            [vertexArray addObject:startPoint];
            [vertexArray addObjectsFromArray:points];
            [self drawVertexForGraphic:_currentLayer withPoints:vertexArray color:color scale:_currentLayer.currentScale.x];
        }
    }
    else if (_currentDrawingMode == UkeDrawingBrushTypeEllipse_edit) { // 可编辑焦点椭圆
        // 焦点椭圆：F1、F2为焦点，P为动点；长轴长为2a，短轴长为2b；焦距为2c。
        // 公式：PF1 + PF2 = 2a；F1F2 = 2c；c^2 = a^2 - b^2；
        // 假设圆心为O，先以O为圆心画出一个水平椭圆，然后再以O为中心旋转到指定的角度
        // 画法：使用bezierPathWithOvalInRect这个api来画，假设M点为rect的左上角顶点，
        CAShapeLayer *ellipseLayer = [CAShapeLayer layer];
        ellipseLayer.bounds = self.currentLayer.bounds;
        ellipseLayer.fillColor = [color colorWithAlphaComponent:0.08].CGColor;
        ellipseLayer.strokeColor = color.CGColor;
        ellipseLayer.lineWidth = width;
        [self.currentLayer addSublayer:ellipseLayer];
        
        if (points.count >= 2) {
            CGPoint F1 = [startPoint CGPointValue];
            CGPoint F2 = [points[0] CGPointValue];
            CGPoint P = [points[1] CGPointValue];
            
            CGPoint O = CGPointMake(fabs(F1.x+F2.x)*0.5, fabs(F1.y+F2.y)*0.5);
            
            CGFloat x = fabs(F1.x-F2.x);
            CGFloat y = fabs(F1.y-F2.y);
            CGFloat F1F2 = sqrt(pow(x,2) + pow(y,2));
            
            x = fabs(P.x-F1.x);
            y = fabs(P.y-F1.y);
            CGFloat PF1 = sqrt(pow(x,2) + pow(y,2));
            
            x = fabs(P.x-F2.x);
            y = fabs(P.y-F2.y);
            CGFloat PF2 = sqrt(pow(x,2) + pow(y,2));
            
            CGFloat a = (PF1 + PF2) * 0.5;
            CGFloat c = F1F2 * 0.5;
            CGFloat b = sqrt(pow(a,2) - pow(c,2));
            
            CGPoint M = CGPointMake(O.x-a, O.y-b);
            
            // 先画水平方向的椭圆
            UIBezierPath *ellipsePath = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(M.x, M.y, 2*a, 2*b)];
            ellipseLayer.path = ellipsePath.CGPath;
            // 再进行旋转。注意：旋转要以圆心O为中心，所以得先把anchorPoint转换到点O。
            // anchorPoint默认是0.5,0.5，即画布中点。下面的操作即可修改锚点
            ellipseLayer.anchorPoint = CGPointMake(O.x/CGRectGetWidth(self.frame), O.y/CGRectGetHeight(self.frame));
            // 接下来计算需要旋转的角度，这个角度的计算跟画箭头的角度计算一样
            CGFloat rotateDegree = [self caculateRotateDegreeWithStartPoint:F1 endPoint:F2];
            // 旋转
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            // 旋转是按水平向右为0度，顺时针规则旋转的
            [ellipseLayer setAffineTransform:CGAffineTransformMakeRotation(radianFromDegree(rotateDegree))];
            [CATransaction commit];
            
            ellipseLayer.position = O;
            
            NSMutableArray *vertexArray = [NSMutableArray array];
            [vertexArray addObject:startPoint];
            [vertexArray addObjectsFromArray:points];
            [self drawVertexForGraphic:_currentLayer withPoints:vertexArray color:color scale:_currentLayer.currentScale.x];
        }
    }
    else if (_currentDrawingMode == UkeDrawingBrushTypeLine_edit) { // 可编辑线段
        if (points.count) {
            for (int i = 0; i < points.count; i ++) {
                CGPoint currentPoint = [points[i] CGPointValue];
                _currentPath = [UIBezierPath bezierPath];
                [_currentPath moveToPoint:_startPoint];
                [_currentPath addLineToPoint:currentPoint];
            }
            
            NSMutableArray *vertexArray = [NSMutableArray array];
            [vertexArray addObject:startPoint];
            [vertexArray addObjectsFromArray:points];
            [self drawVertexForGraphic:_currentLayer withPoints:vertexArray color:color scale:_currentLayer.currentScale.x];
        }
    }
    else if (_currentDrawingMode == UkeDrawingBrushTypeLineArrow_edit) { // 可编辑箭头
        CAShapeLayer *lineArrowLayer = [self drawLineArrowWithStartPoint:_startPoint otherPoints:points width:width color:color scale:_currentLayer.currentScale.x bigArrow:NO];
        lineArrowLayer.frame = _currentLayer.bounds;
        [_currentLayer addSublayer:lineArrowLayer];
        
        NSMutableArray *vertexArray = [NSMutableArray array];
        [vertexArray addObject:startPoint];
        [vertexArray addObjectsFromArray:points];
        [self drawVertexForGraphic:_currentLayer withPoints:vertexArray color:color scale:_currentLayer.currentScale.x];
    }
    else if (_currentDrawingMode == UkeDrawingBrushTypeLineDash_edit) { // 可编辑虚线
        if (points.count) {
            for (int i = 0; i < points.count; i ++) {
                CGPoint currentPoint = [points[i] CGPointValue];
                _currentPath = [UIBezierPath bezierPath];
                [_currentPath moveToPoint:_startPoint];
                [_currentPath addLineToPoint:currentPoint];
            }
            _currentLayer.lineDashPattern = @[@4.f, @4.f];
            
            NSMutableArray *vertexArray = [NSMutableArray array];
            [vertexArray addObject:startPoint];
            [vertexArray addObjectsFromArray:points];
            [self drawVertexForGraphic:_currentLayer withPoints:vertexArray color:color scale:_currentLayer.currentScale.x];
        }
    }
    else if (_currentDrawingMode == UkeDrawingBrushTypeText_edit) { // 可编辑文字框
        
    }
    else if (_currentDrawingMode == UkeDrawingBrushTypeCoordSys_edit) { // 可编辑坐标系
        if (points.count) {
            CGPoint x_start = [points[0] CGPointValue];
            CGPoint x_end = [points[1] CGPointValue];
            
            CGPoint y_start = [points[2] CGPointValue];
            CGPoint y_end = [points[3] CGPointValue];
            
            // 画横竖两条箭头即可
            // 横
            CAShapeLayer *lineArrowLayer1 = [self drawLineArrowWithStartPoint:x_start otherPoints:@[[NSValue valueWithCGPoint:x_end]] width:width color:color scale:_currentLayer.currentScale.x bigArrow:YES];
            lineArrowLayer1.frame = _currentLayer.bounds;
            [_currentLayer addSublayer:lineArrowLayer1];
            // 竖
            CAShapeLayer *lineArrowLayer2 = [self drawLineArrowWithStartPoint:y_start otherPoints:@[[NSValue valueWithCGPoint:y_end]] width:width color:color scale:_currentLayer.currentScale.x bigArrow:YES];
            lineArrowLayer2.frame = _currentLayer.bounds;
            [_currentLayer addSublayer:lineArrowLayer2];
            
            NSMutableArray *vertexArray = [NSMutableArray array];
            [vertexArray addObject:[NSValue valueWithCGPoint:x_end]];
            [vertexArray addObjectsFromArray:@[[NSValue valueWithCGPoint:y_end]]];
            [self drawVertexForCoorSysGraphic:_currentLayer centerPoint:startPoint points:vertexArray color:color scale:_currentLayer.currentScale.x];
            
            if (!targetLayer) {
                [_currentLayer.originalPonits removeAllObjects];
                [_currentLayer.originalPonits addObjectsFromArray:points];
            }
        }
    }
    
    else if (_currentDrawingMode == UkeDrawingBrushTypeEraser) { // 橡皮擦
        if (state&UkeDrawingStateStart) {
            _currentPath = [UIBezierPath bezierPath];
            [_currentPath moveToPoint:_startPoint];
        }
        
        if (points.count) {
            for (int i = 0; i < points.count; i ++) {
                CGPoint currentPoint = [points[i] CGPointValue];
                [_currentPath addLineToPoint:currentPoint];
            }
            // 检测INFINITY的bug
            //FIXME: 这个后期放在哪里检测？
            [self.layer.sublayers.copy enumerateObjectsUsingBlock:^(__kindof CALayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                CGFloat x = obj.position.x;
                CGFloat y = obj.position.y;
                CGFloat w = obj.bounds.size.width;
                CGFloat h = obj.bounds.size.height;
                if (x == INFINITY || y == INFINITY || w == INFINITY || h == INFINITY) {
                    [obj removeFromSuperlayer];
                }
            }];
            
            /* 橡皮擦实现的方案一
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
             */
            
            // 橡皮擦实现的方案二
            // 更新每个形状的mask
            if (!_currentPath) return;

            [self.layer.sublayers enumerateObjectsUsingBlock:^(__kindof CALayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                
                UkeEraseMaskLayer *eraseLayer = (UkeEraseMaskLayer *)obj.mask;
                if (!eraseLayer) {
                    eraseLayer = [[UkeEraseMaskLayer alloc] init];
                }
                eraseLayer.frame = self.bounds;
                
                [eraseLayer appendErasePath:_currentPath.CGPath drawingMode:kCGPathStroke width:width];
                obj.mask = eraseLayer;
            }];
        }
    }else if (_currentDrawingMode == UkeDrawingBrushTypeEraserRectangle) { // 框选删除
        if (points.count) {
            for (int i = 0; i < points.count; i ++) {
                CGPoint currentPoint = [points[i] CGPointValue];
                _currentPath = [UIBezierPath bezierPathWithRect:CGRectMake(_startPoint.x, _startPoint.y, currentPoint.x-_startPoint.x, currentPoint.y-_startPoint.y)];
            }
        }
        
        NSLog(@">>> points: %@", points);
        
        if (state&UkeDrawingStateEnd || forceEnd) {
            [_currentLayer removeFromSuperlayer];
            _currentLayer = nil;
            
            // 检测INFINITY的bug
            [self.layer.sublayers.copy enumerateObjectsUsingBlock:^(__kindof CALayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                CGFloat x = obj.position.x;
                CGFloat y = obj.position.y;
                CGFloat w = obj.bounds.size.width;
                CGFloat h = obj.bounds.size.height;
                if (x == INFINITY || y == INFINITY || w == INFINITY || h == INFINITY) {
                    [obj removeFromSuperlayer];
                }
            }];
            
            /* 橡皮擦实现的方案一
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
             */
            
            // 橡皮擦实现的方案二
            // 更新每个形状的mask
            if (!_currentPath) return;
            
            [self.layer.sublayers enumerateObjectsUsingBlock:^(__kindof UkeDrawingItemLayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                
                if ([obj isKindOfClass:[UkeDrawingItemLayer class]]) {
                    
                    UkeEraseMaskLayer *eraseLayer = (UkeEraseMaskLayer *)obj.mask;
                    if (!eraseLayer) {
                        eraseLayer = [[UkeEraseMaskLayer alloc] init];
                    }
                    eraseLayer.frame = self.bounds;
                    
                    [eraseLayer appendErasePath:_currentPath.CGPath drawingMode:kCGPathFill width:0];
                    obj.mask = eraseLayer;
                }
            }];
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
// bigArrow是为了画坐标系箭头时的特殊配置
- (CAShapeLayer *)drawLineArrowWithStartPoint:(CGPoint)startPoint
                        otherPoints:(NSArray<NSValue *> *)points
                              width:(CGFloat)width
                                        color:(UIColor *)color
                                        scale:(CGFloat)scale
                                     bigArrow:(BOOL)bigArrow {
    if (points.count != 1) {
        return nil;
    }
    
    CAShapeLayer *fatherLayer = [CAShapeLayer layer];
    fatherLayer.frame = self.bounds;
    
    CGPoint endPoint = [points.lastObject CGPointValue];
    CGFloat a = endPoint.x-startPoint.x;
    CGFloat b = startPoint.y-endPoint.y;
    CGFloat lineLength = sqrt(pow(a,2) + pow(b,2)); // 线长
    CGFloat lineWidth = width; // 线宽
    
    scale = fabs(scale);
    if (scale == 0) scale = 1.f;
    scale = MIN(scale, 3.0);
    
    CGFloat arrowDegree = 30.f; // 箭头顶部角度夹角（小于90度比较好）
    CGFloat arrowSideLength = lineWidth * 5.f; // 箭头三角形(等边三角形)两条斜边长
    if (lineWidth <= 1.0) {
        arrowSideLength = 10.f;
    } else if (lineWidth < 4.0) {
        arrowSideLength = 12.f;
    } else {
        arrowSideLength = 15.f;
    }
    
    if (bigArrow) {
        arrowDegree = 60.f;
        
        if (lineWidth <= 2.f) {
            arrowSideLength = lineWidth * 4.f;
        } else {
            arrowSideLength = MIN(lineWidth * 2.f, 10.f);
        }
        
        if (lineWidth <= 1.0) {
            arrowSideLength = 3.f;
        } else if (lineWidth < 4.0) {
            arrowSideLength = 4.f;
        } else {
            arrowSideLength = 5.f;
        }
    }
    
    arrowSideLength = MIN(arrowSideLength * scale, 30.f);
    
    CGFloat arrowDegreeHalf = arrowDegree*0.5; // 箭头夹角的一半
    
    // -----先画水平向右的箭头
    CGFloat arrowWidthHalf = arrowSideLength * sin(radianFromDegree(arrowDegreeHalf)); // 箭头底边宽度的一半
    CGFloat arrowHeight = arrowSideLength * cos(radianFromDegree(arrowDegreeHalf)); // 箭头的高
    
    CGFloat lineIncreased = (lineWidth * 0.5) / tan(radianFromDegree(arrowDegreeHalf)); // 由箭头造成的增加的线宽
    
    CGFloat lineArrowLength = lineLength + lineIncreased; // 总长度
    CGFloat lineArrowWidth = arrowWidthHalf * 2.f; // 总宽度
    
    // 线段
    CAShapeLayer *lineLayer = [[CAShapeLayer alloc] init];
    lineLayer.backgroundColor = [UIColor clearColor].CGColor;
    lineLayer.frame = CGRectMake(startPoint.x, startPoint.y - arrowWidthHalf, lineArrowLength, lineArrowWidth);
    lineLayer.anchorPoint = CGPointMake(0, 0.5);
    lineLayer.position = startPoint; // 由于设置了anchorPoint，所以position就成了startPoint
    lineLayer.lineWidth = lineWidth;
    lineLayer.fillColor = [UIColor clearColor].CGColor;
    lineLayer.strokeColor = color.CGColor;
    [fatherLayer addSublayer:lineLayer];

    UIBezierPath *linePath = [UIBezierPath bezierPath];
    [linePath moveToPoint:CGPointMake(0, arrowWidthHalf)];
    [linePath addLineToPoint:CGPointMake(lineLength, arrowWidthHalf)];
    lineLayer.path = linePath.CGPath;
    
    // 箭头
    CAShapeLayer *arrowLayer = [[CAShapeLayer alloc] init];
    arrowLayer.backgroundColor = [UIColor clearColor].CGColor;
    arrowLayer.frame = CGRectMake(lineArrowLength - arrowHeight, 0, arrowHeight, lineArrowWidth);
    arrowLayer.lineWidth = lineWidth;
    arrowLayer.fillColor = color.CGColor;
    arrowLayer.strokeColor = color.CGColor;
    [lineLayer addSublayer:arrowLayer];
    
    UIBezierPath *arrowPath = [UIBezierPath bezierPath];
    [arrowPath moveToPoint:CGPointMake(0, 0)];
    [arrowPath addLineToPoint:CGPointMake(0, arrowWidthHalf * 2.f)];
    [arrowPath addLineToPoint:CGPointMake(arrowHeight, lineArrowWidth * 0.5)];
    [arrowPath closePath];
    arrowLayer.path = arrowPath.CGPath;
    
    // -----再以最左边为原点进行顺时针旋转
    CGFloat rotateDegree = [self caculateRotateDegreeWithStartPoint:startPoint endPoint:endPoint];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    // 旋转是按水平向右为0度，顺时针规则旋转的
    [lineLayer setAffineTransform:CGAffineTransformMakeRotation(radianFromDegree(rotateDegree))];
    [CATransaction commit];
    
    return fatherLayer;
}

// 计算两个点相对于水平线的角度
- (CGFloat)caculateRotateDegreeWithStartPoint:(CGPoint)startPoint endPoint:(CGPoint)endPoint {
    
    CGFloat a = endPoint.x-startPoint.x;
    CGFloat b = startPoint.y-endPoint.y;
    CGFloat c = sqrt(a*a+b*b);
    
    CGFloat degreeB = 0; // 计算角b，角b为线b的对角
    if (c != 0) {
        degreeB = degreeFromRadian(asin(fabs(b)/c));
    }
    
    // 旋转是按顺时针，这里计算需要旋转的角度
    CGFloat rotateDegree = 0;
    if (a>0 && b>=0) { // 第一象限
        rotateDegree = 360.0-degreeB;
    }else if (a<=0 && b>=0) { // 第二象限
        rotateDegree = 180.0+degreeB;
    }else if (a<=0 && b<0) { // 第三象限
        rotateDegree = 180.0-degreeB;
    }else if (a>0 && b<=0) {// 第四象限
        rotateDegree = degreeB;
    }
    
    return rotateDegree;
}

// 画文字
- (void)drawTextWithText:(NSString *)text
              startPoint:(NSValue *)startPoint
                fontSize:(CGFloat)fontSize
                   color:(UIColor *)color
              identifier:(nonnull NSString *)identifier
             targetLayer:(nullable CALayer *)targetLayer
               transform:(CGPoint)transform {
    
    if (![text isKindOfClass:[NSString class]] || !text.length) {
        return;
    }
    
    fontSize = fabs(fontSize);
    CGPoint point = startPoint.CGPointValue;
    
    if (targetLayer) {
        // 编辑的时候需要重绘，所以这里要先清除子图层
        while (targetLayer.sublayers.lastObject) {
            [targetLayer.sublayers.lastObject removeFromSuperlayer];
        }
        _currentLayer = (UkeDrawingItemLayer *)targetLayer;
    } else {
        UkeDrawingItemLayer *layer = [[UkeDrawingItemLayer alloc] init];

        layer.contentsScale = [UIScreen mainScreen].scale;
        layer.backgroundColor = [UIColor clearColor].CGColor;
        layer.frame = self.bounds;
        [self.layer addSublayer:layer];
        _currentLayer = layer;
        
        _currentLayer.identifier = identifier;
        _currentLayer.type = UkeDrawingBrushTypeText_edit;
        _currentLayer.originalText = text;
        [_currentLayer.originalPonits removeAllObjects];
        [_currentLayer.originalPonits addObject:startPoint];
        _currentLayer.width = fontSize;
        _currentLayer.color = color;
    }
    
    CALayer *textLayer = [self textLayerWithText:text fontSize:fontSize color:color needStroke:NO];
    CGRect textLayerFrame = CGRectMake(point.x, point.y, CGRectGetWidth(textLayer.bounds), CGRectGetHeight(textLayer.bounds));
    
    // 翻转变换
    textLayer.transform = CATransform3DIdentity;
    if (transform.x > 0 && transform.y > 0) {
        textLayer.transform = CATransform3DIdentity;
        
    } else if (transform.x < 0 && transform.y > 0) {
        textLayer.transform = CATransform3DMakeRotation(M_PI, 0, 1, 0);
        textLayerFrame = CGRectMake(point.x-CGRectGetWidth(textLayer.bounds), point.y, CGRectGetWidth(textLayer.bounds), CGRectGetHeight(textLayer.bounds));
        
    } else if (transform.x > 0 && transform.y < 0) {
        textLayer.transform = CATransform3DMakeRotation(M_PI, 1, 0, 0);
        textLayerFrame = CGRectMake(point.x, point.y-CGRectGetHeight(textLayer.bounds), CGRectGetWidth(textLayer.bounds), CGRectGetHeight(textLayer.bounds));
        
    } else if (transform.x < 0 && transform.y < 0) {
        textLayer.transform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
        
        textLayerFrame = CGRectMake(point.x-CGRectGetWidth(textLayer.bounds), point.y-CGRectGetHeight(textLayer.bounds), CGRectGetWidth(textLayer.bounds), CGRectGetHeight(textLayer.bounds));
    }
    
    textLayer.frame = textLayerFrame;
    
    [_currentLayer addSublayer:textLayer];
}

/// 给图形顶点画字母
- (void)drawVertexForGraphic:(UkeDrawingItemLayer *)layer withPoints:(NSArray<NSValue *> *)points color:(UIColor *)color scale:(CGFloat)scale {
    if ([points isPracticalArray] == NO) return;
    
    if (layer.type == UkeDrawingBrushTypeLineArrow_edit) {
        points = [self newVertextPointsForLineArrowWithOriginalPoints:points lineWidth:layer.width];
        if (points == nil) return;
    }
    
    if (layer.showVertex == NO) { // 不显示顶点，但是字母还是得自增
        for (int i = 0; i < points.count; i ++) {
            [self createVertexString];
        }
        return;
    }
    
    scale = fabs(scale);
    if (scale == 0) scale = 1.f;
    scale = MIN(scale, 3.0);
    
    CGFloat pointWidth = 5.f; // 顶点的宽度
    if (layer.width <= 1.0) {
        pointWidth = 5.f;
    } else if (layer.width <= 2.f) {
        pointWidth = 6.f;
    } else {
        pointWidth = 8.f;
    }
    pointWidth = MIN(pointWidth * scale, 14.f);
    
    CGFloat borderWidth = pointWidth * 0.2f; // 顶点描边宽度
    
    CGFloat offsetX = pointWidth * 0.5; // 字母与顶点的x间隔
    CGFloat offsetY = pointWidth * 0.5 - 1.f * scale; // 字母与顶点的y间隔
    
    NSMutableArray *vertexStringList = [NSMutableArray array];
    [points enumerateObjectsUsingBlock:^(NSValue * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        CGPoint point = [obj CGPointValue];
        CALayer *vertexLayer = [CALayer layer];
        vertexLayer.backgroundColor = [UIColor whiteColor].CGColor;
        vertexLayer.borderWidth = borderWidth;
        vertexLayer.borderColor = color.CGColor;
        vertexLayer.cornerRadius = pointWidth * 0.5;
        vertexLayer.masksToBounds = YES;
        vertexLayer.bounds = CGRectMake(0, 0, pointWidth, pointWidth);
        vertexLayer.position = point;
        [layer addSublayer:vertexLayer];
        
        //FIXME: 容易出错
        NSString *vertexString;
        if (layer.currentVertexStringList.count && idx < layer.currentVertexStringList.count) {
            vertexString = [layer.currentVertexStringList objectAtIndex:idx];
        } else {
            vertexString = [self createVertexString];
        }
        CALayer *textLayer = [self textLayerWithText:vertexString fontSize:10*scale color:color needStroke:YES];
        CGPoint position = CGPointMake(point.x + (offsetX + CGRectGetWidth(textLayer.bounds)*0.5),
                                        point.y - (offsetY + CGRectGetWidth(textLayer.bounds)*0.5));
        textLayer.position = position;
        
        [layer addSublayer:textLayer];
        
        [vertexStringList addObject:vertexString];
    }];
    layer.currentVertexStringList = vertexStringList;
}

/// 由于画了箭头的原因，所以箭头顶点值得同比拉长一些
- (NSArray *)newVertextPointsForLineArrowWithOriginalPoints:(NSArray *)originalPoints lineWidth:(CGFloat)lineWidth {
    
    if (originalPoints.count != 2) {
        return nil;
    }
    
    CGPoint startPoint = [originalPoints[0] CGPointValue];
    CGPoint endPoint = [originalPoints[1] CGPointValue];
    
    CGFloat a = endPoint.x-startPoint.x;
    CGFloat b = startPoint.y-endPoint.y;
    CGFloat c = sqrt(a*a+b*b);
    
    CGFloat degreeB = 0; // 计算角b，角b为线b的对角
    if (c != 0) {
        degreeB = degreeFromRadian(asin(fabs(b)/c));
    }
    
    CGFloat addedLength = 2.f;
    if (lineWidth >= 4.f) {
        addedLength = MIN(lineWidth * 2.2, 12.f);
    }
    
    CGFloat addXLength = addedLength * cos(radianFromDegree(degreeB));
    CGFloat addYLength = addedLength * sin(radianFromDegree(degreeB));
    
    CGPoint newEndPoint = endPoint;
    
    // 旋转是按顺时针，这里计算需要旋转的角度
    if (a>0 && b>=0) { // 第一象限
        newEndPoint = CGPointMake(endPoint.x + addXLength, endPoint.y - addYLength);
    }else if (a<=0 && b>=0) { // 第二象限
        newEndPoint = CGPointMake(endPoint.x - addXLength, endPoint.y - addYLength);
    }else if (a<=0 && b<0) { // 第三象限
        newEndPoint = CGPointMake(endPoint.x - addXLength, endPoint.y + addYLength);
    }else if (a>0 && b<=0) {// 第四象限
        newEndPoint = CGPointMake(endPoint.x + addXLength, endPoint.y + addYLength);
    }
    return @[[NSValue valueWithCGPoint:startPoint], [NSValue valueWithCGPoint:newEndPoint]];
}

/// 给坐标系图形顶点画字母：坐标系的字母只有：x和y
/// centerPoint只画点，不画字母。points只画字母不画点
- (void)drawVertexForCoorSysGraphic:(UkeDrawingItemLayer *)layer centerPoint:(NSValue *)centerPoint points:(NSArray<NSValue *> *)points color:(UIColor *)color scale:(CGFloat)scale {
    
    scale = fabs(scale);
    if (scale == 0) scale = 1.f;
    scale = MIN(scale, 3.0);
        
    CGFloat pointWidth = 5.f; // 顶点的宽度
    if (layer.width <= 1.0) {
        pointWidth = 5.f;
    } else if (layer.width <= 2.f) {
        pointWidth = 6.f;
    } else {
        pointWidth = 8.f;
    }
    pointWidth = MIN(pointWidth * scale, 14.f);
    
    CGFloat borderWidth = pointWidth * 0.2f; // 顶点描边宽度
    
    CGFloat offsetX = pointWidth * 0.5; // 字母与顶点的x间隔
    CGFloat offsetY = pointWidth * 0.5 - 1.f; // 字母与顶点的y间隔
    
    // 画中心点
    CALayer *vertexLayer = [CALayer layer];
    vertexLayer.backgroundColor = [UIColor whiteColor].CGColor;
    vertexLayer.borderWidth = borderWidth;
    vertexLayer.borderColor = color.CGColor;
    vertexLayer.cornerRadius = pointWidth * 0.5;
    vertexLayer.masksToBounds = YES;
    vertexLayer.bounds = CGRectMake(0, 0, pointWidth, pointWidth);
    vertexLayer.position = [centerPoint CGPointValue];
    [layer addSublayer:vertexLayer];
    
    NSMutableArray *vertexStringList = [NSMutableArray array];
    [points enumerateObjectsUsingBlock:^(NSValue * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        CGPoint point = [obj CGPointValue];
                
        //FIXME: 容易出错
        NSString *vertexString;
        if (layer.currentVertexStringList.count && idx < layer.currentVertexStringList.count) {
            vertexString = [layer.currentVertexStringList objectAtIndex:idx];
        } else {
            vertexString = (idx == 0)? @"x" : @"y";
        }
        CALayer *textLayer = [self textLayerWithText:vertexString fontSize:10*scale color:color needStroke:YES];
        CGPoint position = CGPointMake(point.x + (offsetX + CGRectGetWidth(textLayer.bounds)*0.5),
                                        point.y - (offsetY + CGRectGetWidth(textLayer.bounds)*0.5));
        textLayer.position = position;
        
        [layer addSublayer:textLayer];
        
        [vertexStringList addObject:vertexString];
    }];
    layer.currentVertexStringList = vertexStringList;
}

/// needStroke: 是否需要给文字加描边，图形顶点字母需要加描边
- (CALayer *)textLayerWithText:(NSString *)text fontSize:(CGFloat)fontSize color:(UIColor *)color needStroke:(BOOL)needStroke {
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineSpacing = 2.0;
    style.maximumLineHeight = fontSize;
    style.minimumLineHeight = fontSize;
    style.lineBreakMode = NSLineBreakByCharWrapping;
    
    NSMutableAttributedString *attri = [[NSMutableAttributedString alloc] initWithString:text];
    [attri addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, text.length)];
    [attri addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:fontSize weight:needStroke ? UIFontWeightBold : UIFontWeightRegular] range:NSMakeRange(0, text.length)];
    [attri addAttribute:NSParagraphStyleAttributeName value:style range:NSMakeRange(0, text.length)];
    [attri addAttribute:NSKernAttributeName value:@(-0.24) range:NSMakeRange(0, text.length)];
    if (needStroke) {
        CGFloat strokeWidth = MIN(fontSize * 0.5, 8.f);
        [attri addAttribute:NSStrokeWidthAttributeName value:@(-strokeWidth) range:NSMakeRange(0, text.length)];
        [attri addAttribute:NSStrokeColorAttributeName value:[UIColor whiteColor] range:NSMakeRange(0, text.length)];
    }

    CGSize textSize = [attri boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin context:NULL].size;
    
    CALayer *textLayer = [CALayer layer];
    textLayer.bounds = CGRectMake(0, 0, textSize.width, textSize.height);
    textLayer.backgroundColor = [UIColor clearColor].CGColor;
    
    UIGraphicsBeginImageContextWithOptions(textLayer.bounds.size, NO, [UIScreen mainScreen].scale);
    [attri drawInRect:textLayer.bounds];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    textLayer.contents = (id)image.CGImage;
    
    return textLayer;
}

- (NSString *)createVertexString {
    NSArray *vertexCharArray = kUkeDrawingPannelVertexCharList;
    NSInteger count = vertexCharArray.count;
    
    currentVertexCharIndex ++;
    
    if (currentVertexCharIndex >= count) {
        currentVertexCharIndex = 0;
        currentVertexNum ++;
    }

    currentVertexCharIndex = MIN(count-1, MAX(0, currentVertexCharIndex));
    currentVertexNum = MAX(0, currentVertexNum);
    
    NSString *vertexString;
    if (currentVertexNum == 0) {
        vertexString = [vertexCharArray objectAtIndex:currentVertexCharIndex];
    } else {
        vertexString = [NSString stringWithFormat:@"%@%zi", [vertexCharArray objectAtIndex:currentVertexCharIndex], currentVertexNum];
    }
    return vertexString;
}

- (void)editWithEditInfo:(UkeGraphicEditInfo *)editInfo identifier:(NSString *)identifier {
    
    if (editInfo.editType == UkeGraphicEditTypeUnknown) return;
    if (!identifier || identifier.length == 0) return;
    
    // 先找到目标图层
    __block UkeDrawingItemLayer *targetLayer;
    [self.layer.sublayers enumerateObjectsUsingBlock:^(UkeDrawingItemLayer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:[UkeDrawingItemLayer class]]) {
            if ([obj.identifier isEqualToString:identifier]) {
                targetLayer = obj;
            }
        }
    }];
    if (!targetLayer) return;
    if (targetLayer.originalPonits.count == 0) return;
        
    CGPoint realScale = CGPointMake(1.f, 1.f);
    if (!CGPointEqualToPoint(editInfo.scale, CGPointZero)) {
        realScale = editInfo.scale;
        targetLayer.currentScale = editInfo.scale;
    } else if (!CGPointEqualToPoint(targetLayer.currentScale, CGPointZero)) { // 由于在移动时，之前做好的缩放并未传过来，所以这里取自己记录的值
        realScale = targetLayer.currentScale;
    }
    
    if (editInfo.editType == UkeGraphicEditTypeEditText) { // 文字的 修改
        targetLayer.originalText = editInfo.text;
        NSValue *startPoint = [NSValue valueWithCGPoint:editInfo.translation];
        [targetLayer.originalPonits removeAllObjects];
        [targetLayer.originalPonits addObject:startPoint];
        [self drawTextWithText:editInfo.text startPoint:startPoint fontSize:targetLayer.width*realScale.x color:targetLayer.color identifier:identifier targetLayer:targetLayer transform:realScale];
        return;
    }
    
    if (targetLayer.type == UkeDrawingBrushTypeCoordSys_edit) { // 坐标系的单点移动
        [self editCoorSysWithEditInfo:editInfo targetLayer:targetLayer identifier:identifier];
        return;
    }
    
    NSMutableArray *editPoints = [NSMutableArray array];
    
    NSMutableArray *mArray = targetLayer.originalPonits.mutableCopy;
    [mArray enumerateObjectsUsingBlock:^(NSValue * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if (editInfo.editType == UkeGraphicEditTypeSinglePointTranslation) { // 单点移动
            
            if (editInfo.singlePointIndex != NSNotFound &&
                editInfo.singlePointIndex < targetLayer.originalPonits.count) {
                
                if (editInfo.singlePointIndex == idx) {
                    CGPoint editPoint =
//                    CGPointMultiply(CGPointAddPoint(targetLayer.currentTranslation, editInfo.translation), realScale);
//                    CGPointAddPoint(CGPointMultiply(targetLayer.currentTranslation, realScale), editInfo.translation);
                    CGPointAddPoint(CGPointMultiply(editInfo.translation, realScale), targetLayer.currentTranslation);
                    
                    [editPoints addObject:[NSValue valueWithCGPoint:editPoint]];
                    
                    [mArray replaceObjectAtIndex:idx withObject:[NSValue valueWithCGPoint:editInfo.translation]];
                    return;
                }
            }
            
            CGPoint point = [obj CGPointValue];
            CGPoint editPoint =
//            CGPointMultiply(CGPointAddPoint(point, targetLayer.currentTranslation), realScale);
            CGPointAddPoint(CGPointMultiply(point, realScale), targetLayer.currentTranslation);
            
            [editPoints addObject:[NSValue valueWithCGPoint:editPoint]];
        } else if (editInfo.editType == UkeGraphicEditTypeEditText) { // 修改文字
            
        } else if (editInfo.editType == UkeGraphicEditTypeWholeTranslation || // 整体移动
                    editInfo.editType == UkeGraphicEditTypeScale) { // 缩放
            CGPoint point = [obj CGPointValue];
            CGPoint editPoint = CGPointMake(point.x*realScale.x + editInfo.translation.x, point.y*realScale.y + editInfo.translation.y);
            [editPoints addObject:[NSValue valueWithCGPoint:editPoint]];
        } else {
            
        }
    }];
    targetLayer.originalPonits = mArray;
    
    if (editInfo.editType == UkeGraphicEditTypeSinglePointTranslation) {
        
    } else if (editInfo.editType == UkeGraphicEditTypeWholeTranslation ||
               editInfo.editType == UkeGraphicEditTypeScale) {
        targetLayer.currentTranslation = editInfo.translation;
    }
    
    if (targetLayer.type == UkeDrawingBrushTypeText ||
        targetLayer.type == UkeDrawingBrushTypeText_edit) {
        NSValue *startPoint = [NSValue valueWithCGPoint:editInfo.translation];
        [targetLayer.originalPonits removeAllObjects];
        [targetLayer.originalPonits addObject:startPoint];
        
        CGFloat fontSize = targetLayer.width * realScale.x;
        [self drawTextWithText:targetLayer.originalText startPoint:startPoint fontSize:fontSize color:targetLayer.color identifier:targetLayer.identifier targetLayer:targetLayer transform:realScale];
    } else {
        UkeDrawingState state = UkeDrawingStateStart|UkeDrawingStateDrawing|UkeDrawingStateEnd;
        
        NSValue *startPoint = editPoints.firstObject;
        NSArray *otherPoints = [editPoints subarrayWithRange:NSMakeRange(1, editPoints.count-1)];

        [self drawWithMode:targetLayer.type drawingState:state startPoint:startPoint otherPoints:otherPoints width:targetLayer.width color:targetLayer.color isFillPath:targetLayer.isFillPath isNormalShape:targetLayer.isNormalShape forceEnd:NO identifier:targetLayer.identifier targetLayer:targetLayer showVertex:targetLayer.showVertex];
    }
}

/// 编辑坐标系
/*
 x轴两个端点的坐标
 (mCenterX - halfX, mCenterY + yMoveDy)
 (mCenterX + halfX + arrowMoveDx, mCenterY + yMoveDy)
 */
- (void)editCoorSysWithEditInfo:(UkeGraphicEditInfo *)editInfo targetLayer:(UkeDrawingItemLayer *)targetLayer  identifier:(NSString *)identifier {
    
    CGPoint realScale = CGPointMake(1.f, 1.f);
    if (!CGPointEqualToPoint(editInfo.scale, CGPointZero)) {
        realScale = editInfo.scale;
        targetLayer.currentScale = editInfo.scale;
    } else if (!CGPointEqualToPoint(targetLayer.currentScale, CGPointZero)) { // 由于在移动时，之前做好的缩放并未传过来，所以这里取自己记录的值
        realScale = targetLayer.currentScale;
    }
    
    NSMutableArray *editArray = [NSMutableArray array];
    NSMutableArray *mArray = targetLayer.originalPonits.mutableCopy;
    [mArray enumerateObjectsUsingBlock:^(NSValue * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        CGPoint point = [obj CGPointValue];
        CGPoint editPoint = CGPointZero;
        
        if (editInfo.editType == UkeGraphicEditTypeWholeTranslation || // 整体移动
                    editInfo.editType == UkeGraphicEditTypeScale) { // 缩放
            
            if (idx == 0 || idx == 1) { // x轴
                editPoint = CGPointMake(point.x*realScale.x + editInfo.translation.x, point.y * realScale.y + targetLayer.currentCoorSysXYTranslation.y*realScale.y + editInfo.translation.y);
            } else if (idx == 2 || idx == 3) { // y轴
                editPoint = CGPointMake(point.x*realScale.x + targetLayer.currentCoorSysXYTranslation.x*realScale.x + editInfo.translation.x, point.y*realScale.y + editInfo.translation.y);
            }
            
        } else if (editInfo.editType == UkeGraphicEditTypeSinglePointTranslation) {
                        
            if (editInfo.singlePointIndex == 0) { // x轴上下移动
                
                if (idx == 0 || idx == 1) {
                    editPoint = CGPointMake(point.x*realScale.x + targetLayer.currentTranslation.x, (point.y+editInfo.translation.y)*realScale.y + targetLayer.currentTranslation.y);
                    
                    targetLayer.currentCoorSysXYTranslation = CGPointMake(targetLayer.currentCoorSysXYTranslation.x, editInfo.translation.y);
                                        
                } else {
                    editPoint =
                    CGPointAddPoint(CGPointMultiply(point, realScale), targetLayer.currentTranslation);
                    
                    editPoint = CGPointMake(editPoint.x + targetLayer.currentCoorSysXYTranslation.x*realScale.x, editPoint.y);

                }
                
            } else if (editInfo.singlePointIndex == 1) { // y轴左右移动
                
                if (idx == 2 || idx == 3) { // y轴两点
                    editPoint = CGPointMake((point.x+editInfo.translation.x)*realScale.x + targetLayer.currentTranslation.x, point.y*realScale.y + targetLayer.currentTranslation.y);
                    
                    targetLayer.currentCoorSysXYTranslation = CGPointMake(editInfo.translation.x, targetLayer.currentCoorSysXYTranslation.y);

                } else { // x轴两点
                    editPoint =
                    CGPointAddPoint(CGPointMultiply(point, realScale), targetLayer.currentTranslation);
                    
                    editPoint = CGPointMake(editPoint.x, editPoint.y + targetLayer.currentCoorSysXYTranslation.y*realScale.y);
                }
                
            } else if (editInfo.singlePointIndex == 2) { // x轴箭头左右移动
                                
                if (idx == 1) { // x右箭头点
                    editPoint =
                    CGPointAddPoint(CGPointMultiply(editInfo.translation, realScale), targetLayer.currentTranslation);
                    
                    CGPoint newPoint = CGPointMake(editInfo.translation.x, editInfo.translation.y-targetLayer.currentCoorSysXYTranslation.y);
                    [mArray replaceObjectAtIndex:idx withObject:[NSValue valueWithCGPoint:newPoint]];
                } else { // 其他点
                    if (idx == 0) { // x左顶点
                        editPoint = CGPointAddPoint(CGPointMultiply(point, realScale), targetLayer.currentTranslation);
                        editPoint = CGPointMake(editPoint.x, editPoint.y + targetLayer.currentCoorSysXYTranslation.y*realScale.y);
                    } else { // y轴两个点
                        editPoint = CGPointAddPoint(CGPointMultiply(point, realScale), targetLayer.currentTranslation);
                        editPoint = CGPointMake(editPoint.x + targetLayer.currentCoorSysXYTranslation.x*realScale.x, editPoint.y);
                    }
                }
                
            } else if (editInfo.singlePointIndex == 3) { // y轴箭头上下移动
                
                if (idx == 3) { // y上箭头点
                    editPoint =
                    CGPointAddPoint(CGPointMultiply(editInfo.translation, realScale), targetLayer.currentTranslation);
                    
                    CGPoint newPoint = CGPointMake(editInfo.translation.x-targetLayer.currentCoorSysXYTranslation.x, editInfo.translation.y);
                    [mArray replaceObjectAtIndex:idx withObject:[NSValue valueWithCGPoint:newPoint]];
                } else { // 其他点
                    if (idx == 2) { // y轴下顶点
                        editPoint = CGPointAddPoint(CGPointMultiply(point, realScale), targetLayer.currentTranslation);
                        editPoint = CGPointMake(editPoint.x + targetLayer.currentCoorSysXYTranslation.x*realScale.x, editPoint.y);
                    } else { // x轴两个点
                        editPoint = CGPointAddPoint(CGPointMultiply(point, realScale), targetLayer.currentTranslation);
                        editPoint = CGPointMake(editPoint.x, editPoint.y + targetLayer.currentCoorSysXYTranslation.y*realScale.y);
                    }
                }
                
            }
        }
        
        [editArray addObject:[NSValue valueWithCGPoint:editPoint]];
    }];
    
    targetLayer.originalPonits = mArray;
    
    if (editInfo.editType == UkeGraphicEditTypeSinglePointTranslation) {
        
    } else if (editInfo.editType == UkeGraphicEditTypeWholeTranslation ||
               editInfo.editType == UkeGraphicEditTypeScale) {
        targetLayer.currentTranslation = editInfo.translation;
    }
    
    CGPoint centerPoint = CGPointMake([editArray[2] CGPointValue].x, [editArray[0] CGPointValue].y);
    UkeDrawingState state = UkeDrawingStateStart|UkeDrawingStateDrawing|UkeDrawingStateEnd;
    
    [self drawWithMode:UkeDrawingBrushTypeCoordSys_edit drawingState:state startPoint:[NSValue valueWithCGPoint:centerPoint] otherPoints:editArray.copy width:targetLayer.width*realScale.x color:targetLayer.color isFillPath:targetLayer.isFillPath isNormalShape:targetLayer.isNormalShape forceEnd:NO identifier:identifier targetLayer:targetLayer showVertex:targetLayer.showVertex];
}

- (void)deleteWithIdentifiers:(NSSet *)identifiers {
    [self.layer.sublayers.copy enumerateObjectsUsingBlock:^(UkeDrawingItemLayer *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:[UkeDrawingItemLayer class]]) {
            if ([identifiers containsObject:obj.identifier]) {
                [obj removeFromSuperlayer];
            }
        }
    }];
}

- (void)deleteCurrentPage {
    while (self.layer.sublayers.lastObject) {
        [self.layer.sublayers.lastObject removeFromSuperlayer];
    }
}

- (void)createLayerWithWidth:(CGFloat)width
                       color:(UIColor *)color
                  isFillPath:(BOOL)isFillPath
           isEraserRectangle:(BOOL)isEraserRectangle
                  identifier:(NSString *)identifier {
    
    UkeDrawingItemLayer *layer = [[UkeDrawingItemLayer alloc] init];
    layer.identifier = identifier;
    layer.contentsScale = [UIScreen mainScreen].scale;
    layer.backgroundColor = [UIColor clearColor].CGColor;
    if (isEraserRectangle) {
        layer.fillColor = [[UIColor greenColor] colorWithAlphaComponent:0.1].CGColor;
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

- (void)dealloc {
    NSLog(@"UkePaintingView dealloc");
}

@end
