#import "CQConnectionCreationViewController.h"

#import "CQConnectionsController.h"
#import "CQConnectionEditViewController.h"

#import <ChatCore/MVChatConnection.h>

@implementation CQConnectionCreationViewController
- (id) init {
	if (!(self = [super init]))
		return nil;
	self.delegate = self;
	return self;
}

- (void) dealloc {
	[_editViewController release];
	[super dealloc];
}

- (void) viewWillAppear:(BOOL) animated {
	_editViewController = [[CQConnectionEditViewController alloc] init];
	_editViewController.newConnection = YES;

	MVChatConnection *connection = [[MVChatConnection alloc] initWithType:MVChatConnectionIRCType];
	connection.server = @"<<placeholder>>";
	connection.preferredNickname = @"<<default>>";
	connection.realName = @"<<default>>";
	connection.username = @"<<default>>";
	connection.automaticallyConnect = YES;
	connection.serverPort = 0;

	_editViewController.connection = connection;
	[connection release];

	UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector( cancel:)];
	_editViewController.navigationItem.leftBarButtonItem = cancelItem;
	[cancelItem release];

	UIBarButtonItem *saveItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector( commit:)];
	_editViewController.navigationItem.rightBarButtonItem = saveItem;
	[saveItem release];

	_editViewController.navigationItem.rightBarButtonItem.tag = UIBarButtonSystemItemSave;
	_editViewController.navigationItem.rightBarButtonItem.enabled = NO;

	[self pushViewController:_editViewController animated:NO];
}

- (void) viewDidDisappear:(BOOL) animated {
	[_editViewController release];
	_editViewController = nil;
}

- (void) cancel:(id) sender {
	[self.parentViewController dismissModalViewControllerAnimated:YES];
}

- (void) commit:(id) sender {
	MVChatConnection *connection = _editViewController.connection;
	if ([connection.server isEqualToString:@"<<placeholder>>"]) {
		[self cancel:sender];
		return;
	}

	if ([connection.preferredNickname isEqualToString:@"<<default>>"])
		connection.preferredNickname = NSUserName();

	if ([connection.realName isEqualToString:@"<<default>>"])
		connection.realName = NSFullUserName();

	if ([connection.username isEqualToString:@"<<default>>"]) {
		UIDevice *device = [UIDevice currentDevice];
		if ([[device model] hasPrefix:@"iPhone"])
			connection.username = @"iphone";
		else if ([[device model] hasPrefix:@"iPod"])
			connection.username = @"ipod";
		else
			connection.username = @"user";
	}

	[[CQConnectionsController defaultController] addConnection:connection];

	[connection connect];

	[self.parentViewController dismissModalViewControllerAnimated:YES];
}

- (void) navigationController:(UINavigationController *) navigationController willShowViewController:(UIViewController *) viewController animated:(BOOL) animated {
	// Workaround a bug where viewWillAppear: is not called when this navigation controller is a modal view.
	[viewController viewWillAppear:animated];
}

- (void) navigationController:(UINavigationController *) navigationController didShowViewController:(UIViewController *) viewController animated:(BOOL) animated {
	// Workaround a bug where viewDidAppear: is not called when this navigation controller is a modal view.
	[viewController viewDidAppear:animated];
}
@end
