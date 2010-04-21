//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

#import "CQUserInfoController.h"

#import "CQUserInfoViewController.h"

#import "CQColloquyApplication.h"

@implementation CQUserInfoController
- (id) init {
	if (!(self = [super init]))
		return nil;

	self.delegate = self;

	if ([self respondsToSelector:@selector(setModalPresentationStyle:)])
		self.modalPresentationStyle = UIModalPresentationFormSheet;

	return self;
}

- (void) dealloc {
	self.delegate = nil;

	[_userInfoViewController release];
	[_user release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	if (_userInfoViewController)
		return;

	_userInfoViewController = [[CQUserInfoViewController alloc] init];
	_userInfoViewController.user = _user;

	UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close:)];
	_userInfoViewController.navigationItem.leftBarButtonItem = doneItem;
	[doneItem release];

	[self pushViewController:_userInfoViewController animated:NO];
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	_previousStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;

	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:animated];
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	[[UIApplication sharedApplication] setStatusBarStyle:_previousStatusBarStyle animated:animated];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation {
	return ![[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"];
}

#pragma mark -

- (IBAction) close:(id) sender {
	[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];
}

#pragma mark -

@synthesize user = _user;

- (void) setUser:(MVChatUser *) user {
	id old = _user;
	_user = [user retain];
	[old release];

	_userInfoViewController.user = user;
}
@end
