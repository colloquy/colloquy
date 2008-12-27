#import "CQChatController.h"

#import "CQChatRoomController.h"
#import "CQChatListViewController.h"
#import "CQConnectionsController.h"
#import "CQDirectChatController.h"

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatUser.h>
#import <ChatCore/MVDirectChatConnection.h>

@interface CQChatController (CQChatControllerPrivate)
- (void) _showNextChatControllerAnimated:(BOOL) animated;
@end

#pragma mark -

@implementation CQChatController
+ (CQChatController *) defaultController {
	static BOOL creatingSharedInstance = NO;
	static CQChatController *sharedInstance = nil;

	if (!sharedInstance && !creatingSharedInstance) {
		creatingSharedInstance = YES;
		sharedInstance = [[self alloc] init];
	}

	return sharedInstance;
}

- (id) init {
	if (!(self = [super init]))
		return nil;

	_chatControllers = [[NSMutableArray alloc] init];

	self.title = NSLocalizedString(@"Colloquies", @"Colloquies tab title");
	self.tabBarItem.image = [UIImage imageNamed:@"colloquies.png"];
	self.delegate = self;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_joinedRoom:) name:MVChatRoomJoinedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_gotRoomMessage:) name:MVChatRoomGotMessageNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_gotPrivateMessage:) name:MVChatConnectionGotPrivateMessageNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_gotDirectChatMessage:) name:MVDirectChatConnectionGotMessageNotification object:nil];

	return self;
}

- (void) dealloc {
	[_chatListViewController release];
	[_chatControllers release];
	[_nextController release];
	[_nextRoomName release];
	[_nextRoomConnection release];
	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	if (!_chatListViewController)
		_chatListViewController = [[CQChatListViewController alloc] init];

	[self pushViewController:_chatListViewController animated:NO];

	if (_nextController)
		[self _showNextChatControllerAnimated:NO];
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	self.totalImportantUnreadCount = 0;

	_active = YES;
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	_active = NO;
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation {
	// This should support UIDeviceOrientationLandscapeLeft too, but convertPoint: returns bad results in that orientation.
	return (interfaceOrientation == UIDeviceOrientationPortrait || interfaceOrientation == UIDeviceOrientationLandscapeRight);
}

#pragma mark -

static NSComparisonResult sortControllersAscending(CQDirectChatController *chatController1, CQDirectChatController *chatController2, void *context) {
	NSComparisonResult result = [chatController1.connection.displayName caseInsensitiveCompare:chatController2.connection.displayName];
	if (result != NSOrderedSame)
		return result;

	result = [chatController1.connection.nickname caseInsensitiveCompare:chatController2.connection.nickname];
	if (result != NSOrderedSame)
		return result;

	if (chatController1.connection < chatController2.connection)
		return NSOrderedAscending;
	if (chatController1.connection > chatController2.connection)
		return NSOrderedDescending;

	if ([chatController1 isMemberOfClass:[CQChatRoomController class]] && [chatController2 isMemberOfClass:[CQDirectChatController class]])
		return NSOrderedAscending;
	if ([chatController1 isMemberOfClass:[CQDirectChatController class]] && [chatController2 isMemberOfClass:[CQChatRoomController class]])
		return NSOrderedDescending;

	return [chatController1.title caseInsensitiveCompare:chatController2.title];
}

#pragma mark -

- (void) _sortChatControllers {
	[_chatControllers sortUsingFunction:sortControllersAscending context:NULL];
}

- (void) _joinedRoom:(NSNotification *) notification {
	MVChatRoom *room = notification.object;
	CQChatRoomController *roomController = [self chatViewControllerForRoom:room ifExists:NO];
	[roomController joined];
}

- (void) _gotRoomMessage:(NSNotification *) notification {
	// We do this here to make sure we catch early messages right when we join (this includes dircproxy's dump).
	MVChatRoom *room = notification.object;

	CQChatRoomController *controller = [self chatViewControllerForRoom:room ifExists:NO];
	[controller addMessage:notification.userInfo];

	MVChatUser *sender = [notification.userInfo objectForKey:@"user"];
	if (!sender.localUser)
		[_chatListViewController addMessagePreview:notification.userInfo forChatController:controller];
}

- (void) _gotPrivateMessage:(NSNotification *) notification {
	MVChatUser *user = notification.object;
	MVChatUser *sender = user;

	if (user.localUser && [notification.userInfo objectForKey:@"target"])
		user = [notification.userInfo objectForKey:@"target"];

	BOOL hideFromUser = NO;
	if ([[notification.userInfo objectForKey:@"notice"] boolValue]) {
		if (![self chatViewControllerForUser:user ifExists:YES])
			hideFromUser = YES;

		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatAlwaysShowNotices"])
			hideFromUser = NO;
	}

	if (!hideFromUser) {
		CQDirectChatController *controller = [self chatViewControllerForUser:user ifExists:NO userInitiated:NO];
		[controller addMessage:notification.userInfo];

		if (!sender.localUser)
			[_chatListViewController addMessagePreview:notification.userInfo forChatController:controller];
	}
}

- (void) _gotDirectChatMessage:(NSNotification *) notification {
	MVDirectChatConnection *connection = notification.object;

	CQDirectChatController *controller = [self chatViewControllerForDirectChatConnection:connection ifExists:NO];
	[controller addMessage:notification.userInfo];

	[_chatListViewController addMessagePreview:notification.userInfo forChatController:controller];
}

- (void) _showNextChatControllerAnimated:(BOOL) animated {
	if (self.visibleViewController != _chatListViewController)
		return;

	[_chatListViewController selectChatViewController:_nextController animatedSelection:NO animatedScroll:animated];
	[self pushViewController:(UIViewController *)_nextController animated:animated];

	[_nextController release];
	_nextController = nil;
}

- (void) _showNextChatController {
	[self _showNextChatControllerAnimated:YES];
}

#pragma mark -

- (NSDictionary *) persistentStateForConnection:(MVChatConnection *) connection {
	NSArray *controllers = [self chatViewControllersForConnection:connection];
	if (!controllers.count)
		return nil;

	NSMutableDictionary *state = [[NSMutableDictionary alloc] init];
	NSMutableArray *controllerStates = [[NSMutableArray alloc] init];

	for (id <CQChatViewController> controller in controllers) {
		if (![controller respondsToSelector:@selector(persistentState)])
			continue;

		NSDictionary *controllerState = controller.persistentState;
		if (!controllerState.count || ![controllerState objectForKey:@"class"])
			continue;

		[controllerStates addObject:controllerState];
	}

	if (controllerStates.count)
		[state setObject:controllerStates forKey:@"chatControllers"];

	[controllerStates release];

	return [state autorelease];
}

- (void) restorePersistentState:(NSDictionary *) state forConnection:(MVChatConnection *) connection {
	for (NSDictionary *controllerState in [state objectForKey:@"chatControllers"]) {
		NSString *className = [controllerState objectForKey:@"class"];
		Class class = NSClassFromString(className);
		if (!class)
			continue;

		id <CQChatViewController> controller = [[class alloc] initWithPersistentState:controllerState usingConnection:connection];
		if (!controller)
			continue;

		[_chatControllers addObject:controller];
		[controller release];

		if ([[controllerState objectForKey:@"active"] boolValue]) {
			id old = _nextController;
			_nextController = [controller retain];
			[old release];
		}
	}

	[self _sortChatControllers];
}

#pragma mark -

- (NSInteger) totalImportantUnreadCount {
	return _totalImportantUnreadCount;
}

- (void) setTotalImportantUnreadCount:(NSInteger) count {
	if (_active && self.visibleViewController == _chatListViewController)
		return;

	if (count < 0) count = 0;

	_totalImportantUnreadCount = count;

	if (_totalImportantUnreadCount) {
		_chatListViewController.navigationItem.title = [NSString stringWithFormat:NSLocalizedString(@"%@ (%u)", @"Unread count view title, uses the view's normal title with a number"), self.title, _totalImportantUnreadCount];
		self.tabBarItem.badgeValue = [NSString stringWithFormat:@"%u", _totalImportantUnreadCount];
	} else {
		_chatListViewController.navigationItem.title = self.title;
		self.tabBarItem.badgeValue = nil;
	}
}

#pragma mark -

- (void) showNewChatActionSheet {
	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.delegate = self;

	[sheet addButtonWithTitle:NSLocalizedString(@"Join a Chat Room", @"Join a Chat Room button title")];
	[sheet addButtonWithTitle:NSLocalizedString(@"Message a User", @"Message a User button title")];
	[sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	sheet.cancelButtonIndex = 2;

	[sheet showInView:self.view.window];
	[sheet release];
}

- (void) showChatControllerWhenAvailableForRoomNamed:(NSString *) roomName andConnection:(MVChatConnection *) connection {
	NSParameterAssert(roomName != nil);
	NSParameterAssert(connection != nil);

	[_nextRoomName release];
	_nextRoomName = nil;

	[_nextRoomConnection release];
	_nextRoomConnection = nil;

	MVChatRoom *room = [connection joinedChatRoomWithName:roomName];
	if (room) {
		CQChatRoomController *controller = [self chatViewControllerForRoom:room ifExists:YES];
		if (controller) {
			[self showChatController:controller animated:YES];
			return;
		}
	}

	_nextRoomName = [roomName copy];
	_nextRoomConnection = [connection retain];
}

- (void) showChatController:(id <CQChatViewController>) controller animated:(BOOL) animated {
	[_nextRoomName release];
	_nextRoomName = nil;

	[_nextRoomConnection release];
	_nextRoomConnection = nil;

	BOOL delayed = (animated && self.visibleViewController != _chatListViewController);
	if (delayed) {
		id old = _nextController;
		_nextController = [controller retain];
		[old release];
	}

	[self popToRootViewControllerAnimated:animated];

	if (!delayed) {
		[_chatListViewController selectChatViewController:controller animatedSelection:NO animatedScroll:animated];
		[self pushViewController:(UIViewController *)controller animated:animated];
	}
}

- (void) navigationController:(UINavigationController *) navigationController willShowViewController:(UIViewController *) viewController animated:(BOOL) animated {
	if (viewController == _chatListViewController)
		self.totalImportantUnreadCount = 0;
}

- (void) navigationController:(UINavigationController *) navigationController didShowViewController:(UIViewController *) viewController animated:(BOOL) animated {
	if (viewController == _chatListViewController && _nextController)
		[self performSelector:@selector(_showNextChatController) withObject:nil afterDelay:0.33];
}

#pragma mark -

@synthesize chatViewControllers = _chatControllers;

- (NSArray *) chatViewControllersForConnection:(MVChatConnection *) connection {
	NSParameterAssert(connection != nil);

	NSMutableArray *result = [NSMutableArray array];

	for (id <CQChatViewController> controller in _chatControllers)
		if (controller.connection == connection)
			[result addObject:controller];

	return result;
}

- (NSArray *) chatViewControllersOfClass:(Class) class {
	NSParameterAssert(class != NULL);

	NSMutableArray *result = [NSMutableArray array];

	for (id <CQChatViewController> controller in _chatControllers)
		if ([controller isMemberOfClass:class])
			[result addObject:controller];

	return result;
}

- (NSArray *) chatViewControllersKindOfClass:(Class) class {
	NSParameterAssert(class != NULL);

	NSMutableArray *result = [NSMutableArray array];

	for (id <CQChatViewController> controller in _chatControllers)
		if ([controller isKindOfClass:class])
			[result addObject:controller];

	return result;
}

#pragma mark -

- (CQChatRoomController *) chatViewControllerForRoom:(MVChatRoom *) room ifExists:(BOOL) exists {
	NSParameterAssert(room != nil);

	for (id <CQChatViewController> controller in _chatControllers)
		if ([controller isMemberOfClass:[CQChatRoomController class]] && [controller.target isEqual:room])
			return (CQChatRoomController *)controller;

	CQChatRoomController *controller = nil;

	if (!exists) {
		if ((controller = [[CQChatRoomController alloc] initWithTarget:room])) {
			[_chatControllers addObject:controller];
			[controller release];

			[self _sortChatControllers];

			[_chatListViewController addChatViewController:controller];

			if (room.connection == _nextRoomConnection && _nextRoomName && [_nextRoomConnection joinedChatRoomWithName:_nextRoomName] == room)
				[self showChatController:controller animated:YES];

			return controller;
		}
	}

	return nil;
}

- (CQDirectChatController *) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists {
	return [self chatViewControllerForUser:user ifExists:exists userInitiated:YES];
}

- (CQDirectChatController *) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists userInitiated:(BOOL) initiated {
	NSParameterAssert(user != nil);

	for (id <CQChatViewController> controller in _chatControllers)
		if ([controller isMemberOfClass:[CQDirectChatController class]] && [controller.target isEqual:user])
			return (CQDirectChatController *)controller;

	CQDirectChatController *controller = nil;

	if (!exists) {
		if ((controller = [[CQDirectChatController alloc] initWithTarget:user])) {
			[_chatControllers addObject:controller];
			[controller release];

			[self _sortChatControllers];

			[_chatListViewController addChatViewController:controller];

			return controller;
		}
	}

	return nil;
}

- (CQDirectChatController *) chatViewControllerForDirectChatConnection:(MVDirectChatConnection *) connection ifExists:(BOOL) exists {
	NSParameterAssert(connection != nil);

	for (id <CQChatViewController> controller in _chatControllers)
		if ([controller isMemberOfClass:[CQDirectChatController class]] && [controller.target isEqual:connection])
			break;

	CQDirectChatController *controller = nil;

	if (!exists) {
		if ((controller = [[CQDirectChatController alloc] initWithTarget:connection])) {
			[_chatControllers addObject:controller];
			[controller release];

			[self _sortChatControllers];

			[_chatListViewController addChatViewController:controller];

			return controller;
		}
	}

	return nil;
}

#pragma mark -

- (void) closeViewController:(id <CQChatViewController>) controller {
	if ([controller respondsToSelector:@selector(close)])
		[controller close];
	[_chatControllers removeObjectIdenticalTo:controller];
}
@end
