//
//  UkeDrawingConstants.h
//  DrawPanel
//
//  Created by liqian on 2019/1/26.
//  Copyright © 2019 liqian. All rights reserved.
//

#ifndef UkeDrawingConstants_h
#define UkeDrawingConstants_h

#import "UIColor+Extension.h"
#import "NSObject+UkeKit.h"

// Color.
#ifndef UkeColorRGBA
    #define UkeColorRGBA(r, g, b, a) \
            [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:a]

    #define UkeColorRGB(r, g, b)     UkeColorRGBA(r, g, b, 1.f)

    #define UkeRandomColor \
            UkeColorRGB(arc4random_uniform(256), arc4random_uniform(256), arc4random_uniform(256))
#endif

#ifndef UkeColorHexA
    #define UkeColorHexA(_hex_, a) \
            UkeColorRGBA((((_hex_) & 0xFF0000) >> 16), (((_hex_) & 0xFF00) >> 8), ((_hex_) & 0xFF), a)

    #define UkeColorHex(_hex_)   UkeColorHexA(_hex_, 1.0)
#endif


// 所有的绘画类型
#define kUkeAllDrawingBrushTypes  @[@"brush", @"line", @"ellipse", @"rectangle", @"texttool", @"eraser", @"eraserrectangle", @"linearrow", @"triangle", @"star", @"pressurepen"]

typedef NS_ENUM(NSInteger, UkeDrawingBrushType) {
    UkeDrawingBrushTypeUnKnown = -1,
    UkeDrawingBrushTypeBrush = 0, //! 线
    UkeDrawingBrushTypeLine, //! 线段
    UkeDrawingBrushTypeEllipse, //! 椭圆
    UkeDrawingBrushTypeRectangle, //! 矩形框
    UkeDrawingBrushTypeText, //! 文字
    UkeDrawingBrushTypeEraser, //! 橡皮擦
    UkeDrawingBrushTypeEraserRectangle, //! 框选删除
    UkeDrawingBrushTypeLineArrow, //! 箭头
    UkeDrawingBrushTypeTriangle, //! 三角形
    UkeDrawingBrushTypeStar, //! 五角星
    UkeDrawingBrushTypePressurePen, //! 按压笔
};

typedef NS_OPTIONS(NSUInteger, UkeDrawingState) {
    UkeDrawingStateUnknown = 0,
    UkeDrawingStateStart = 1<<0,
    UkeDrawingStateDrawing = 1<<1,
    UkeDrawingStateEnd = 1<<2
};

typedef NS_ENUM(NSUInteger, UkePannelMode) {
    UkePannelModeWhite = 0,
    UkePannelModeBlack = 1,
};

static inline UkeDrawingBrushType brushTypeFromNSString(NSString *string) {
    UkeDrawingBrushType brushType = UkeDrawingBrushTypeUnKnown;
    if ([string isPracticalString] == NO) {
        return brushType;
    }
    
    if ([string isEqualToString:@"brush"]) {
        brushType = UkeDrawingBrushTypeBrush;
    } else if ([string isEqualToString:@"line"]) {
        brushType = UkeDrawingBrushTypeLine;
    } else if ([string isEqualToString:@"ellipse"]) {
        brushType = UkeDrawingBrushTypeEllipse;
    } else if ([string isEqualToString:@"rectangle"]) {
        brushType = UkeDrawingBrushTypeRectangle;
    } else if ([string isEqualToString:@"texttool"]) {
        brushType = UkeDrawingBrushTypeText;
    } else if ([string isEqualToString:@"eraser"]) {
        brushType = UkeDrawingBrushTypeEraser;
    } else if ([string isEqualToString:@"eraserrectangle"]) {
        brushType = UkeDrawingBrushTypeEraserRectangle;
    } else if ([string isEqualToString:@"linearrow"]) {
        brushType = UkeDrawingBrushTypeLineArrow;
    } else if ([string isEqualToString:@"triangle"]) {
        brushType = UkeDrawingBrushTypeTriangle;
    } else if ([string isEqualToString:@"star"]) {
        brushType = UkeDrawingBrushTypeStar;
    } else if ([string isEqualToString:@"pressurepen"]) {
        brushType = UkeDrawingBrushTypePressurePen;
    }
    return brushType;
}

static inline NSString * NSStringFromBrushType(UkeDrawingBrushType brushType) {
    NSString *brushTypeString = @"unKnown";
    switch (brushType) {
        case UkeDrawingBrushTypeUnKnown:
            brushTypeString = @"unKnown";
            break;
            
        case UkeDrawingBrushTypeBrush:
            brushTypeString = @"brush";
            break;
            
        case UkeDrawingBrushTypeLine:
            brushTypeString = @"line";
            break;
            
        case UkeDrawingBrushTypeEllipse:
            brushTypeString = @"ellipse";
            break;
            
        case UkeDrawingBrushTypeRectangle:
            brushTypeString = @"rectangle";
            break;
            
        case UkeDrawingBrushTypeText:
            brushTypeString = @"texttool";
            break;
            
        case UkeDrawingBrushTypeEraser:
            brushTypeString = @"eraser";
            break;
            
        case UkeDrawingBrushTypeEraserRectangle:
            brushTypeString = @"eraserrectangle";
            break;
            
        case UkeDrawingBrushTypeLineArrow:
            brushTypeString = @"linearrow";
            break;
            
        case UkeDrawingBrushTypeTriangle:
            brushTypeString = @"triangle";
            break;
            
        case UkeDrawingBrushTypeStar:
            brushTypeString = @"star";
            break;
            
        case UkeDrawingBrushTypePressurePen:
            brushTypeString = @"pressurepen";
            break;
    }
    return brushTypeString;
}

#endif /* UkeDrawingConstants_h */
