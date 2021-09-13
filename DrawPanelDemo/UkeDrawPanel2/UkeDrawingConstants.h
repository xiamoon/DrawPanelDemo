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
#define kUkeAllDrawingBrushTypes  @[@"brush", @"line", @"ellipse", @"rectangle", @"texttool", @"eraser", @"eraserrectangle", @"linearrow", @"triangle", @"star", @"pressurepen", @"polygon_edit", @"circle_edit", @"ellipse_edit", @"line_edit", @"linearrow_edit", @"linedash_edit", @"text_edit", @"coord_sys", @"edit_regular", @"edit_delete", @"edit_delete_page"]

// 顶点下标字母列表
#define kUkeDrawingPannelVertexCharList @[@"A",@"B",@"C",@"D",@"E",@"F",@"G",@"H",@"I",@"J",@"K",@"L",@"M",@"N",@"O",@"P",@"Q",@"R",@"S",@"T",@"U",@"V",@"W",@"X",@"Y",@"Z"]

//TODO: 服务端改了1.0版本的画笔、橡皮、框选删除的数据
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
    UkeDrawingBrushTypePolygon_edit, //!< 可编辑多边形
    UkeDrawingBrushTypeCircle_edit, //!< 可编辑同心圆
    UkeDrawingBrushTypeEllipse_edit, //!< 可编辑焦点椭圆
    UkeDrawingBrushTypeLine_edit, //!< 可编辑线段
    UkeDrawingBrushTypeLineArrow_edit, //!< 可编辑箭头
    UkeDrawingBrushTypeLineDash_edit, //!< 可编辑虚线
    UkeDrawingBrushTypeText_edit, //!< 可编辑文字框
    UkeDrawingBrushTypeCoordSys_edit, //!< 可编辑坐标系
    UkeDrawingBrushTypeEdit_regular, //!< 对现有的图形进行编辑
    UkeDrawingBrushTypeEdit_delete, //!< 删除指定图形
    UkeDrawingBrushTypeEdit_deletePage, //!< 删除所有图形
};

static inline UkeDrawingBrushType brushTypeFromNSString(NSString *string) {
    UkeDrawingBrushType brushType = UkeDrawingBrushTypeUnKnown;
    
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
    } else if ([string isEqualToString:@"polygon_edit"]) {
        brushType = UkeDrawingBrushTypePolygon_edit;
    } else if ([string isEqualToString:@"circle_edit"]) {
        brushType = UkeDrawingBrushTypeCircle_edit;
    } else if ([string isEqualToString:@"ellipse_edit"]) {
        brushType = UkeDrawingBrushTypeEllipse_edit;
    } else if ([string isEqualToString:@"line_edit"]) {
        brushType = UkeDrawingBrushTypeLine_edit;
    } else if ([string isEqualToString:@"linearrow_edit"]) {
        brushType = UkeDrawingBrushTypeLineArrow_edit;
    } else if ([string isEqualToString:@"linedash_edit"]) {
        brushType = UkeDrawingBrushTypeLineDash_edit;
    } else if ([string isEqualToString:@"text_edit"]) {
        brushType = UkeDrawingBrushTypeText_edit;
    } else if ([string isEqualToString:@"coord_sys"]) {
        brushType = UkeDrawingBrushTypeCoordSys_edit;
    } else if ([string isEqualToString:@"edit_regular"]) {
        brushType = UkeDrawingBrushTypeEdit_regular;
    } else if ([string isEqualToString:@"edit_delete"]) {
        brushType = UkeDrawingBrushTypeEdit_delete;
    } else if ([string isEqualToString:@"edit_delete_page"]) {
        brushType = UkeDrawingBrushTypeEdit_deletePage;
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
            
        case UkeDrawingBrushTypePolygon_edit:
            brushTypeString = @"polygon_edit";
            break;
            
        case UkeDrawingBrushTypeCircle_edit:
            brushTypeString = @"circle_edit";
            break;
            
        case UkeDrawingBrushTypeEllipse_edit:
            brushTypeString = @"ellipse_edit";
            break;
            
        case UkeDrawingBrushTypeLine_edit:
            brushTypeString = @"line_edit";
            break;
            
        case UkeDrawingBrushTypeLineArrow_edit:
            brushTypeString = @"linearrow_edit";
            break;
            
        case UkeDrawingBrushTypeLineDash_edit:
            brushTypeString = @"linedash_edit";
            break;
            
        case UkeDrawingBrushTypeText_edit:
            brushTypeString = @"text_edit";
            break;
            
        case UkeDrawingBrushTypeCoordSys_edit:
            brushTypeString = @"coord_sys";
            break;
            
        case UkeDrawingBrushTypeEdit_regular:
            brushTypeString = @"edit_regular";
            break;
            
        case UkeDrawingBrushTypeEdit_delete:
            brushTypeString = @"edit_delete";
        break;
            
        case UkeDrawingBrushTypeEdit_deletePage:
            brushTypeString = @"edit_delete_page";
        break;
    }
    return brushTypeString;
}

static inline CGPoint CGPointAddPoint(CGPoint point1, CGPoint point2) {
    return CGPointMake(point1.x + point2.x, point1.y + point2.y);
}

static inline CGPoint CGPointMultiply(CGPoint point1, CGPoint value) {
    return CGPointMake(point1.x * value.x, point1.y * value.y);
}

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

// 图形编辑
typedef enum {
    UkeGraphicEditTypeUnknown = -1,
    UkeGraphicEditTypeWholeTranslation = 0, // 整体移动
    UkeGraphicEditTypeScale, // 缩放
    UkeGraphicEditTypeSinglePointTranslation, // 单点移动
    UkeGraphicEditTypeEditText, // 编辑文字
} UkeGraphicEditType;


#endif /* UkeDrawingConstants_h */
