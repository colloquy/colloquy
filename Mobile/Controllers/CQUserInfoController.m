//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

#import "CQUserInfoController.h"

#import "CQUserInfoViewController.h"

#import "MVChatUser.h"

#import "CQColloquyApplication.h"

@implementation CQUserInfoController
- (void) viewDidLoad {
	if (!_rootViewController) {
		CQUserInfoViewController *userInfoViewController = [[CQUserInfoViewController alloc] init];
		userInfoViewController.user = _user;

		_rootViewController = userInfoViewController;
	}

	[super viewDidLoad];

	UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close:)];
	_rootViewController.navigationItem.leftBarButtonItem = doneItem;
}

#pragma mark -

- (void) setUser:(MVChatUser *) user {
	_user = user;

	((CQUserInfoViewController *)_rootViewController).user = user;
}
@end
