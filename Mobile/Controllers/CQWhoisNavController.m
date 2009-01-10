//  CQWhoisNavController.m
//  Mobile Colloquy
//
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

- (void) viewWillAppear:(BOOL) animated {
	_whoisViewController = [[CQWhoisViewController alloc] init];
	_whoisViewController.user = _user;

	UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close:)];
	_whoisViewController.navigationItem.leftBarButtonItem = doneItem;
	[doneItem release];

	[self pushViewController:_whoisViewController animated:NO];
}

- (void) viewDidDisappear:(BOOL) animated {
	[_whoisViewController release];
	_whoisViewController = nil;
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"])
		return (interfaceOrientation == UIInterfaceOrientationPortrait);
	return (UIInterfaceOrientationIsLandscape(interfaceOrientation) || interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark -

- (void) navigationController:(UINavigationController *) navigationController willShowViewController:(UIViewController *) viewController animated:(BOOL) animated {
	// Workaround a bug where viewWillDisappear: and viewWillAppear: are not called when this navigation controller is a modal view.
	if (navigationController.topViewController != viewController)
		[navigationController.topViewController viewWillDisappear:animated];
	[viewController viewWillAppear:animated];
}

- (void) navigationController:(UINavigationController *) navigationController didShowViewController:(UIViewController *) viewController animated:(BOOL) animated {
	// Workaround a bug where viewDidAppear: is not called when this navigation controller is a modal view.
	[viewController viewDidAppear:animated];
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
