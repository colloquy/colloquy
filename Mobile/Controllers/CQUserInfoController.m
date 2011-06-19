//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

#import "CQUserInfoController.h"

#import "CQUserInfoViewController.h"

#import "MVChatUser.h"

@implementation CQUserInfoController
- (void) dealloc {
	[_user release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	if (!_rootViewController) {
		CQUserInfoViewController *userInfoViewController = [[CQUserInfoViewController alloc] init];
		userInfoViewController.user = _user;

		_rootViewController = userInfoViewController;
	}

	[super viewDidLoad];

	UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close:)];
	_rootViewController.navigationItem.leftBarButtonItem = doneItem;
	[doneItem release];
}

#pragma mark -

@synthesize user = _user;

- (void) setUser:(MVChatUser *) user {
	id old = _user;
	_user = [user retain];
	[old release];

	((CQUserInfoViewController *)_rootViewController).user = user;
}
@end
