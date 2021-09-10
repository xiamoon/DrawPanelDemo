//
//  UkeDrawingCanvas.m
//  DrawPanel
//
//  Created by liqian on 2019/1/26.
//  Copyright © 2019 liqian. All rights reserved.
//

#import "UkeDrawingCanvas.h"
#import "UkePaintingView.h"
#import "UkeDrawingPointsParser.h"

@interface UkeDrawingCanvas ()
@property (nonatomic, strong) UkeDrawingPointsParser *pointParser;
//! 绘画展示的layer
@property (nonatomic, strong) UkePaintingView *paintingView;


@property (nonatomic, strong) UIPanGestureRecognizer *pan;
@property (nonatomic, strong) NSMutableArray *drawPointsArray;
@property (nonatomic, assign) NSUInteger mockActionId;
@property (nonatomic, assign) UkeDrawingBrushType brushType;
@property (nonatomic, assign) CGFloat brushWidth;
@property (nonatomic, strong) UIColor *brushColor;
@property (nonatomic, assign) CGFloat eraserWidth;

@end

@implementation UkeDrawingCanvas

- (instancetype)init {
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.layer.masksToBounds = YES;
        
        self.pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGestureAction:)];
        self.pan.enabled = NO;
        [self addGestureRecognizer:self.pan];
        self.drawPointsArray = [NSMutableArray array];
        
        _pointParser = [[UkeDrawingPointsParser alloc] init];
        
        _paintingView = [[UkePaintingView alloc] init];
        [self addSubview:_paintingView];
    }
    return self;
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    [super willMoveToSuperview:newSuperview];
    if (newSuperview) {
        _paintingView.frame = self.bounds;
    }
}

- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    [self caculateScale];
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    _paintingView.frame = self.bounds;
}

- (void)setVisualSize:(CGSize)visualSize {
    _visualSize = visualSize;
    [self caculateScale];
}

- (void)setBgColor:(UIColor *)bgColor {
    self.backgroundColor = bgColor;
}

- (void)caculateScale {
    CGFloat visualWidth = _visualSize.width;
    if (visualWidth == 0) {
        visualWidth = CGRectGetWidth(self.frame);
    }
    CGFloat visualHeight = _visualSize.height;
    if (visualHeight == 0) {
        visualHeight = CGRectGetHeight(self.frame);
    }
    
    _pointParser.scaleX = visualWidth / 800.0;
    _pointParser.scaleY = visualHeight / 450.0;
}

- (UIImage *)currentContents {
    return _paintingView.currentContents;
}

- (void)setCurrentContents:(UIImage *)currentContents {
    [_paintingView setCurrentContents:currentContents];
}

- (void)drawWithPoints:(NSArray<NSArray *> *)points {
    __weak typeof(self)weakSelf = self;
    
    [self.pointParser parseWithPoints:points completion:^(UkeDrawingPointsParser * _Nonnull parser) {
        if ([parser brushType] == UkeDrawingBrushTypeText) {  // 文字
            [weakSelf.paintingView drawTextWithText:[parser text]
                                         startPoint:[parser startPoint]
                                           fontSize:[parser lineWidth]
                                              color:[parser color]];
        }else {
            [weakSelf.paintingView drawWithMode:[parser brushType] drawingState:[parser drawingState] startPoint:[parser startPoint] otherPoints:[parser realDrawPoints] width:[parser lineWidth] color:[parser color] isFillPath:[parser isFillPath] isNormalShape:[parser isNormalShape] forceEnd:[parser forceEndPreviousPath]];
        }
    }];
}

- (void)authorizeDrawing {
    self.userInteractionEnabled = YES;
    self.pan.enabled = YES;
    
    self.brushType = UkeDrawingBrushTypeBrush;
    self.brushColor = [UIColor blackColor];
    self.brushWidth = 5.f;
    self.eraserWidth = 60.f;
}
- (void)unAuthorizeDrawing {
    self.userInteractionEnabled = NO;
    self.pan.enabled = NO;
}

- (void)chooseBrush {
    self.brushType = UkeDrawingBrushTypeBrush;
}
- (void)chooseEraser {
    self.brushType = UkeDrawingBrushTypeEraser;
}

- (void)handlePanGestureAction:(UIGestureRecognizer *)pan {
    
    if (pan.state == UIGestureRecognizerStatePossible) {
        NSLog(@">>> UIGestureRecognizerStatePossible");
        return;
    }

    CGPoint point = [pan locationInView:self];
    switch (pan.state) {
        case UIGestureRecognizerStateBegan:
            [self formatPoint:point start:YES end:NO];
            break;
            
        case UIGestureRecognizerStateChanged:
            [self formatPoint:point start:NO end:NO];
            break;
            
        default:
            [self formatPoint:point start:NO end:YES];
            break;
    }
}

- (void)formatPoint:(CGPoint)point start:(BOOL)start end:(BOOL)end {
    if (self.brushType == UkeDrawingBrushTypeBrush) {
        [self formatBrushPoint:point start:start end:end];
    } else if (self.brushType == UkeDrawingBrushTypeEraser) {
        [self formatEraserPoint:point start:start end:end];
    }
}

- (void)formatBrushPoint:(CGPoint)point start:(BOOL)start end:(BOOL)end {
    CGPoint newPoint = CGPointMake(point.x / self.pointParser.scaleX, point.y / self.pointParser.scaleY);

    if (start) {
        [self.drawPointsArray removeAllObjects];
        self.mockActionId ++;
        
        NSArray *pointArray = @[
            [NSString stringWithFormat:@"%.2f", newPoint.x],
            [NSString stringWithFormat:@"%.2f", newPoint.y],
            @(self.mockActionId),
            NSStringFromBrushType(UkeDrawingBrushTypeBrush),
            @[
                @(self.brushWidth),
                [self brushColorString]
            ],
            @[],
            @[[NSUUID UUID].UUIDString]
        ];
        [self.drawPointsArray addObject:pointArray];
    } else if (end) {
        NSArray *pointArray = @[
            [NSString stringWithFormat:@"%.2f", newPoint.x],
            [NSString stringWithFormat:@"%.2f", newPoint.y],
            @(self.mockActionId),
            @(YES)
        ];
        [self.drawPointsArray addObject:pointArray];
        [self outPutDrawPoints];
    } else {
        NSArray *pointArray = @[
            [NSString stringWithFormat:@"%.2f", newPoint.x],
            [NSString stringWithFormat:@"%.2f", newPoint.y],
            @(self.mockActionId)
        ];
        [self.drawPointsArray addObject:pointArray];
    }
}

- (void)formatEraserPoint:(CGPoint)point start:(BOOL)start end:(BOOL)end {
    CGPoint newPoint = CGPointMake(point.x / self.pointParser.scaleX, point.y / self.pointParser.scaleY);

    if (start) {
        [self.drawPointsArray removeAllObjects];
        self.mockActionId ++;

        NSArray *pointArray = @[
            [NSString stringWithFormat:@"%.2f", newPoint.x],
            [NSString stringWithFormat:@"%.2f", newPoint.y],
            @(self.mockActionId),
            NSStringFromBrushType(UkeDrawingBrushTypeEraser),
            @[@(self.eraserWidth)]
        ];
        [self.drawPointsArray addObject:pointArray];
    } else if (end) {
        NSArray *pointArray = @[
            [NSString stringWithFormat:@"%.2f", newPoint.x],
            [NSString stringWithFormat:@"%.2f", newPoint.y],
            @(self.mockActionId),
            @(YES)
        ];
        [self.drawPointsArray addObject:pointArray];
        [self outPutDrawPoints];
    } else {
        NSArray *pointArray = @[
            [NSString stringWithFormat:@"%.2f", newPoint.x],
            [NSString stringWithFormat:@"%.2f", newPoint.y],
            @(self.mockActionId)
        ];
        [self.drawPointsArray addObject:pointArray];
    }
}

- (NSString *)brushColorString {
    NSString *string = [self.brushColor colorToHexString];
    if ([string isPracticalString] == NO) {
        string = @"#EF4C4F";
    }
    return string;
}

- (void)outPutDrawPoints {
    for (int i = 0; i < 10; i++) {
        [self drawWithPoints:self.drawPointsArray];
    }
    [self.drawPointsArray removeAllObjects];
}

- (void)dealloc {
    NSLog(@"手绘板canvas销毁");
}

@end
