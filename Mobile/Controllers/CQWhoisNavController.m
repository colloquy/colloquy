//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

#import "CQWhoisNavController.h"

#import "CQWhoisViewController.h"

@implementation CQWhoisNavController
- (id) init {
	if (!(self = [super init]))
		return nil;
	self.delegate = self;
	return self;
}

- (void) dealloc {
	[_whoisViewController release];
	[_user release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	if (_whoisViewController)
		return;

	_whoisViewController = [[CQWhoisViewController alloc] init];
	_whoisViewController.user = _user;

	UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close:)];
	_whoisViewController.navigationItem.leftBarButtonItem = doneItem;
	[doneItem release];

	[self pushViewController:_whoisViewController animated:NO];
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
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"])
		return (interfaceOrientation == UIInterfaceOrientationPortrait);
	return YES;
}

#pragma mark -

- (IBAction) close:(id) sender {
	[self dismissModalViewControllerAnimated:YES];
}

#pragma mark -

@synthesize user = _user;

- (void) setUser:(MVChatUser *) user {
	id old = _user;
	_user = [user retain];
	[old release];

	_whoisViewController.user = user;
}
@end
