//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

#import "CQModalNavigationController.h"

@class MVChatUser;

@interface CQUserInfoController : CQModalNavigationController <UINavigationControllerDelegate> {
	@protected
	MVChatUser *_user;
}
@property (nonatomic, retain) MVChatUser *user;
@end
