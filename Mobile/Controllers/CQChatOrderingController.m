#import "CQChatOrderingController.h"

#import "CQDirectChatController.h"
#import "CQChatRoomController.h"
#import "CQConsoleController.h"

#import "CQConnectionsController.h"

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatUser.h>

typedef BOOL (^CQMatchingResult)(id <CQChatViewController> chatViewController);

static NSComparisonResult sortControllersAscending(id controller1, id controller2, void *context) {
	if ([controller1 isKindOfClass:[CQDirectChatController class]] && [controller2 isKindOfClass:[CQDirectChatController class]]) {
		CQDirectChatController *chatController1 = controller1;
		CQDirectChatController *chatController2 = controller2;
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

		if ([chatController1 isMemberOfClass:[CQConsoleController class]])
			return NSOrderedAscending;
		if ([chatController2 isMemberOfClass:[CQConsoleController class]])
			return NSOrderedDescending;
		if ([chatController1 isMemberOfClass:[CQChatRoomController class]] && [chatController2 isMemberOfClass:[CQDirectChatController class]])
			return NSOrderedAscending;
		if ([chatController1 isMemberOfClass:[CQDirectChatController class]] && [chatController2 isMemberOfClass:[CQChatRoomController class]])
			return NSOrderedDescending;

		return [chatController1.title caseInsensitiveCompare:chatController2.title];
	}

	if ([controller1 isKindOfClass:[CQDirectChatController class]])
		return NSOrderedAscending;

	if ([controller2 isKindOfClass:[CQDirectChatController class]])
		return NSOrderedDescending;

	return NSOrderedSame;
}

@implementation CQChatOrderingController
@synthesize chatViewControllers = _chatControllers;

+ (CQChatOrderingController *) defaultController {
	static BOOL creatingSharedInstance = NO;
	static CQChatOrderingController *sharedInstance = nil;

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

	return self;
}

#pragma mark -

- (void) _sortChatControllers {
	[_chatControllers sortUsingFunction:sortControllersAscending context:NULL];
}

- (NSUInteger) indexOfViewController:(id <CQChatViewController>) controller {
	return [_chatControllers indexOfObjectIdenticalTo:controller];
}

- (void) addViewController:(id <CQChatViewController>) controller {
	[_chatControllers addObject:controller];

	[self _sortChatControllers];

	NSDictionary *notificationInfo = @{@"controller": controller};
	[[NSNotificationCenter defaultCenter] postNotificationName:CQChatControllerAddedChatViewControllerNotification object:self userInfo:notificationInfo];
}

- (void) removeViewController:(id <CQChatViewController>) controller {
	[_chatControllers removeObject:controller];
}

#if ENABLE(FILE_TRANSFERS)
- (void) _addFileTransferController:(CQFileTransferController *) controller {
	[self addViewController:(id <CQChatViewController>)controller];
}
#endif

#pragma mark -

- (CQConsoleController *) consoleViewControllerForConnection:(MVChatConnection *) connection ifExists:(BOOL) exists {
	return [self chatViewControllerForConnection:connection ifExists:exists userInitiated:YES];
}

- (CQConsoleController *) chatViewControllerForConnection:(MVChatConnection *) connection ifExists:(BOOL) exists userInitiated:(BOOL) initiated {
	NSParameterAssert(connection != nil);

	for (id <CQChatViewController> controller in _chatControllers)
		if ([controller isMemberOfClass:[CQConsoleController class]] && controller.target == connection)
			return (CQConsoleController *)controller;

	CQConsoleController *controller = nil;

	if (!exists) {
		if ((controller = [[CQConsoleController alloc] initWithTarget:connection])) {
			[[CQChatOrderingController defaultController] addViewController:controller];
			return controller;
		}
	}

	return nil;
}

- (NSArray *) chatViewControllersForConnection:(MVChatConnection *) connection {
	NSParameterAssert(connection != nil);

	NSMutableArray *result = [NSMutableArray array];

	for (id controller in _chatControllers)
		if ([controller conformsToProtocol:@protocol(CQChatViewController)] && ((id <CQChatViewController>) controller).connection == connection)
			[result addObject:controller];

	return result;
}

- (NSArray *) chatViewControllersOfClass:(Class) class {
	NSParameterAssert(class != NULL);

	NSMutableArray *result = [NSMutableArray array];

	for (id controller in _chatControllers)
		if ([controller isMemberOfClass:class])
			[result addObject:controller];

	return result;
}

- (NSArray *) chatViewControllersKindOfClass:(Class) class {
	NSParameterAssert(class != NULL);

	NSMutableArray *result = [NSMutableArray array];

	for (id controller in _chatControllers)
		if ([controller isKindOfClass:class])
			[result addObject:controller];

	return result;
}

#pragma mark -

- (CQChatRoomController *) chatViewControllerForRoom:(MVChatRoom *) room ifExists:(BOOL) exists {
	NSParameterAssert(room != nil);

	for (id <CQChatViewController> controller in _chatControllers)
		if ([controller isMemberOfClass:[CQChatRoomController class]] && controller.target == room)
			return (CQChatRoomController *)controller;

	CQChatRoomController *controller = nil;

	if (!exists) {
		if ((controller = [[CQChatRoomController alloc] initWithTarget:room])) {
			[[CQChatOrderingController defaultController] addViewController:controller];

			if (room.connection == [CQChatController defaultController].nextRoomConnection)
				[[CQChatController defaultController] showChatController:controller animated:YES];

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
		if ([controller isMemberOfClass:[CQDirectChatController class]] && controller.target == user)
			return (CQDirectChatController *)controller;

	CQDirectChatController *controller = nil;

	if (!exists) {
		if ((controller = [[CQDirectChatController alloc] initWithTarget:user])) {
			[[CQChatOrderingController defaultController] addViewController:controller];
			return controller;
		}
	}

	return nil;
}

- (CQDirectChatController *) chatViewControllerForDirectChatConnection:(MVDirectChatConnection *) connection ifExists:(BOOL) exists {
	NSParameterAssert(connection != nil);

	for (id <CQChatViewController> controller in _chatControllers)
		if ([controller isMemberOfClass:[CQDirectChatController class]] && controller.target == connection)
			return (CQDirectChatController *)controller;

	CQDirectChatController *controller = nil;

	if (!exists) {
		if ((controller = [[CQDirectChatController alloc] initWithTarget:connection])) {
			[[CQChatOrderingController defaultController] addViewController:controller];
			return controller;
		}
	}

	return nil;
}

#if ENABLE(FILE_TRANSFERS)
- (CQFileTransferController *) chatViewControllerForFileTransfer:(MVFileTransfer *) transfer ifExists:(BOOL) exists {
	NSParameterAssert(transfer != nil);

	for (id controller in _chatControllers)
		if ([controller isMemberOfClass:[CQFileTransferController class]] && ((CQFileTransferController *)controller).transfer == transfer)
			return controller;

	if (!exists) {
		CQFileTransferController *controller = [[CQFileTransferController alloc] initWithTransfer:transfer];
		if (controller) {
			[self _addFileTransferController:controller];
			return [controller autorelease];
		}
	}

	return nil;
}
#endif

#pragma mark -

- (BOOL) connectionHasAnyChatRooms:(MVChatConnection *) connection {
	for (id <CQChatViewController> chatViewController in [self chatViewControllersForConnection:connection])
		if ([chatViewController.target isKindOfClass:[MVChatRoom class]])
			return YES;
	return NO;
}

- (BOOL) connectionHasAnyPrivateChats:(MVChatConnection *) connection {
	for (id <CQChatViewController> chatViewController in [self chatViewControllersForConnection:connection])
		if ([chatViewController.target isKindOfClass:[MVChatUser class]])
			return YES;
	return NO;
}

#pragma mark -

- (id <CQChatViewController>) _enumerateChatViewControllersFromChatController:(id <CQChatViewController>) chatViewController withOption:(NSEnumerationOptions) options requiringActivity:(BOOL) requiringActivity requiringHighlight:(BOOL) requiringHighlight {
	if (_chatControllers.count < 2)
		return [_chatControllers lastObject];

	NSUInteger index = [_chatControllers indexOfObject:chatViewController];
	NSArray *firstHalf = nil;
	NSArray *secondHalf = nil;

	if (options & NSEnumerationReverse) {
		firstHalf = [_chatControllers subarrayWithRange:NSMakeRange(0, index)];
		secondHalf = [_chatControllers subarrayWithRange:NSMakeRange((index + 1), (_chatControllers.count - (index + 1)))];
	} else {
		firstHalf = [_chatControllers subarrayWithRange:NSMakeRange((index + 1), (_chatControllers.count - (index + 1)))];
		secondHalf = [_chatControllers subarrayWithRange:NSMakeRange(0, index)];
	}

	id <CQChatViewController> (^findNearestMatchForBlock)(CQMatchingResult) = ^(CQMatchingResult block) {
		__block id <CQChatViewController> chatViewController = nil;
		[firstHalf enumerateObjectsWithOptions:options usingBlock:^(id object, NSUInteger index, BOOL *stop) {
			if (block(object)) {
				chatViewController = object;

				*stop = YES;
			}
		}];

		if (!chatViewController) {
			[secondHalf enumerateObjectsWithOptions:options usingBlock:^(id object, NSUInteger index, BOOL *stop) {
				if (block(object)) {
					chatViewController = object;

					*stop = YES;
				}
			}];
		}

		return chatViewController;
	};

	if (requiringActivity && requiringHighlight) {
		return findNearestMatchForBlock(^BOOL(id <CQChatViewController> chatViewController) {
			return chatViewController.unreadCount && chatViewController.importantUnreadCount;
		});
	}

	if (requiringHighlight) {
		return findNearestMatchForBlock(^BOOL(id <CQChatViewController> chatViewController) {
			return chatViewController.importantUnreadCount;
		});
	}

	if (requiringActivity) {
		return findNearestMatchForBlock(^BOOL(id <CQChatViewController> chatViewController) {
			return chatViewController.unreadCount;
		});
	}
	
	return nil;
}

- (id <CQChatViewController>) chatViewControllerPreceedingChatController:(id <CQChatViewController>) chatViewController requiringActivity:(BOOL) requiringActivity requiringHighlight:(BOOL) requiringHighlight {
	if (!_chatControllers.count)
		return nil;

	if (!requiringActivity && !requiringHighlight) {
		NSUInteger index = [_chatControllers indexOfObjectIdenticalTo:chatViewController];
		if (!index)
			return [_chatControllers lastObject];
		return _chatControllers[(index - 1)];
	}

	return [self _enumerateChatViewControllersFromChatController:chatViewController withOption:NSEnumerationReverse requiringActivity:requiringActivity requiringHighlight:requiringHighlight];
}

- (id <CQChatViewController>) chatViewControllerFollowingChatController:(id <CQChatViewController>) chatViewController requiringActivity:(BOOL) requiringActivity requiringHighlight:(BOOL) requiringHighlight {
	if (!requiringActivity && !requiringHighlight) {
		NSUInteger index = [_chatControllers indexOfObjectIdenticalTo:chatViewController];
		if (index == (_chatControllers.count - 1))
			return _chatControllers[0];
		return _chatControllers[(index + 1)];
	}

	return [self _enumerateChatViewControllersFromChatController:chatViewController withOption:0 requiringActivity:requiringActivity requiringHighlight:requiringHighlight];
}
@end
