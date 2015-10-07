//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

#import "CQModalNavigationController.h"

@class MVChatUser;

NS_ASSUME_NONNULL_BEGIN

@interface CQUserInfoController : CQModalNavigationController
@property (nonatomic, strong) MVChatUser *user;
@end

NS_ASSUME_NONNULL_END
