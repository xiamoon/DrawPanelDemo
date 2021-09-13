//
//  UkeGraphicEditInfo.h
//  ZMUke
//
//  Created by liqian on 2020/4/21.
//  Copyright © 2020 zmlearn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UkeDrawingConstants.h"

NS_ASSUME_NONNULL_BEGIN

@interface UkeGraphicEditInfo : NSObject

@property (nonatomic, assign) UkeGraphicEditType editType;

@property (nonatomic, assign) NSInteger singlePointIndex; //!< 单点移动时，被移动的点的下标，其他移动方式时，忽略此值

@property (nonatomic, assign) CGPoint translation;

@property (nonatomic, assign) CGPoint scale;

@property (nonatomic, copy) NSString *text; //!< 修改文字时的新文字
@end

NS_ASSUME_NONNULL_END

