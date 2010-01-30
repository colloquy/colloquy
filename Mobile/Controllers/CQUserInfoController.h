//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

@class CQUserInfoViewController;
@class MVChatUser;

@interface CQUserInfoController : UINavigationController <UINavigationControllerDelegate> {
	@protected
	CQUserInfoViewController *_userInfoViewController;
	MVChatUser *_user;
	UIStatusBarStyle _previousStatusBarStyle;
}
@property (nonatomic, retain) MVChatUser *user;

- (IBAction) close:(id) sender;
@end
