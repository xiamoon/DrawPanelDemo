//
//  NSObject+UkeKit.m
//  UkeUtilsPlatform
//
//  Created by liqian on 2020/9/10.
//

#import "NSObject+UkeKit.h"

@implementation NSObject (UkeKit)

- (BOOL)isValidString {
    return [self isKindOfClass:[NSString class]];
}

- (BOOL)isPracticalString {
    if ([self isValidString] == NO) {
        return NO;
    }
    
    NSString *str = (NSString *)self;
    if (str.length == 0) {
        return NO;
    }
    
    if ([str rangeOfString:@"null"].location != NSNotFound) {
        return NO;
    }
    
    return YES;
}

- (BOOL)isValidArray {
    return [self isKindOfClass:[NSArray class]];
}

- (BOOL)isPracticalArray {
    if (![self isValidArray]) {
        return NO;
    }
    NSArray *array = (NSArray *)self;
    return array.count > 0;
}

- (BOOL)isValidDict {
    return [self isKindOfClass:[NSDictionary class]];
}

- (BOOL)isPracticalDict {
    if (![self isValidDict]) {
        return NO;
    }
    NSDictionary *dict = (NSDictionary *)self;
    return dict.allKeys.count > 0;
}

- (BOOL)isValidNumber {
    return [self isKindOfClass:[NSNumber class]];
}

- (BOOL)isValidStringOrNumber {
    return [self isValidString] || [self isValidNumber];
}

- (nullable NSString *)getStringValue {
    if ([self isValidString]) {
        return (NSString *)self;
    }
    if ([self isValidNumber]) {
        return [NSString stringWithFormat:@"%@", self];
    }
    return nil;
}

- (BOOL)isIphoneX {
    BOOL isiPhoneX = NO;
    if (@available(iOS 11.0, *)) {
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            isiPhoneX = [[UIApplication sharedApplication]delegate].window.safeAreaInsets.bottom > 0.0;
        }
    }
    return isiPhoneX;
}

- (UkekeyboardType)isCurrentKeyboardType {

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isDisplayed = YES"];
    UITextInputMode * dic = [[[UITextInputMode activeInputModes] filteredArrayUsingPredicate:predicate] lastObject];
    NSString *currentKeyboardName = [dic valueForKey:@"extendedDisplayName"];
    
    if([currentKeyboardName isEqualToString:@"简体拼音"] ||
       [currentKeyboardName isEqualToString:@"表情符号"] ||
       [currentKeyboardName isEqualToString:@"English (US)"]) {
        return UkeSystemkeyboard;
    }else if ([currentKeyboardName isEqualToString:@"百度"]) {
        return UkeBaiDukeyboard;
    }else if ([currentKeyboardName isEqualToString:@"搜狗"]) {
        return UkeSouGoukeyboard;
    }else if ([currentKeyboardName isEqualToString:@"讯飞"]) {
        return UkeXunFeikeyboard;
    }
    
    return UkeSystemkeyboard;

}


@end
