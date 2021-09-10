//
//  UIColor+Extension.m
//  ZMUke
//
//  Created by liqian on 2019/7/7.
//  Copyright © 2019 zmlearn. All rights reserved.
//

#import "UIColor+Extension.h"

@implementation UIColor (Extension)

static inline NSUInteger hexStrToInt(NSString *str) {
    uint32_t result = 0;
    const char *UTF8String = [str UTF8String];
    if (UTF8String == NULL) {
        return result;
    }
    
    @try {
        sscanf([str UTF8String], "%X", &result);
    } @catch (NSException *exception) {} @finally {}
    
    return result;
}

static BOOL hexStrToRGBA(NSString *str,
                         CGFloat *r, CGFloat *g, CGFloat *b, CGFloat *a) {
    NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    str = [[str stringByTrimmingCharactersInSet:set] uppercaseString];
    if ([str hasPrefix:@"#"]) {
        str = [str substringFromIndex:1];
    } else if ([str hasPrefix:@"0X"]) {
        str = [str substringFromIndex:2];
    }
    
    NSUInteger length = [str length];
    //         RGB            RGBA          RRGGBB        RRGGBBAA
    if (length != 3 && length != 4 && length != 6 && length != 8) {
        return NO;
    }
    
    //RGB,RGBA,RRGGBB,RRGGBBAA
    if (length < 5) {
        *r = hexStrToInt([str substringWithRange:NSMakeRange(0, 1)]) / 15.0f;
        *g = hexStrToInt([str substringWithRange:NSMakeRange(1, 1)]) / 15.0f;
        *b = hexStrToInt([str substringWithRange:NSMakeRange(2, 1)]) / 15.0f;
        if (length == 4)  *a = hexStrToInt([str substringWithRange:NSMakeRange(3, 1)]) / 15.0f;
        else *a = 1;
    } else {
        *r = hexStrToInt([str substringWithRange:NSMakeRange(0, 2)]) / 255.0f;
        *g = hexStrToInt([str substringWithRange:NSMakeRange(2, 2)]) / 255.0f;
        *b = hexStrToInt([str substringWithRange:NSMakeRange(4, 2)]) / 255.0f;
        if (length == 8) *a = hexStrToInt([str substringWithRange:NSMakeRange(6, 2)]) / 255.0f;
        else *a = 1;
    }
    return YES;
}

+ (instancetype)colorWithHexString:(NSString *)hexStr {
    if (nil == hexStr) {
        return nil;
    }
    
    CGFloat r, g, b, a;
    if (hexStrToRGBA(hexStr, &r, &g, &b, &a)) {
        return [UIColor colorWithRed:r green:g blue:b alpha:a];
    }
    return nil;
}

- (BOOL)isBlack {
    
    CGFloat red, green, blue, alpha;
    [self getRed:&red green:&green blue:&blue alpha:&alpha];
    
    return 0 == red && 0 == green && 0 == blue && 1 == alpha;
}

- (NSString *)colorToHexString {
    CGFloat red, green, blue, alpha;
#if SD_UIKIT
    if (![self getRed:&red green:&green blue:&blue alpha:&alpha]) {
        [self getWhite:&red alpha:&alpha];
        green = red;
        blue = red;
    }
#else
    @try {
        [self getRed:&red green:&green blue:&blue alpha:&alpha];
    }
    @catch (NSException *exception) {
        [self getWhite:&red alpha:&alpha];
        green = red;
        blue = red;
    }
#endif
    
    red = roundf(red * 255.f);
    green = roundf(green * 255.f);
    blue = roundf(blue * 255.f);
    alpha = roundf(alpha * 255.f);
    
#warning - 这里没有取alpha，可能有问题
    uint hex = ((uint)red << 16) | ((uint)green << 8) | ((uint)blue);
    
    return [NSString stringWithFormat:@"#%06x", hex];
}

@end
