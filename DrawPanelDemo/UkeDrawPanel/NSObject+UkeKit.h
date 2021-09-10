//
//  NSObject+UkeKit.h
//  UkeUtilsPlatform
//
//  Created by liqian on 2020/9/10.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, UkekeyboardType) {
    UkeSystemkeyboard = 0, // 系统键盘
    UkeBaiDukeyboard,//百度
    UkeXunFeikeyboard,//讯飞
    UkeSouGoukeyboard,// 搜狗
};

@interface NSObject (UkeKit)

- (BOOL)isValidString;
- (BOOL)isPracticalString;

- (BOOL)isValidArray;
- (BOOL)isPracticalArray;

- (BOOL)isValidDict;
- (BOOL)isPracticalDict;

- (BOOL)isValidNumber;
- (BOOL)isValidStringOrNumber;

- (nullable NSString *)getStringValue;

- (BOOL)isIphoneX;

///  判断当前键盘类型
- (UkekeyboardType)isCurrentKeyboardType;

@end

NS_ASSUME_NONNULL_END
