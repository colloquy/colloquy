#import "CQChatOrderingController.h"

#import "CQChatRoomController.h"
#import "CQConsoleController.h"

#import "CQConnectionsController.h"

#import "CQBouncerConnection.h"
#import "CQBouncerSettings.h"

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatUser.h>

#import "NSNotificationAdditions.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *roomOrdering;
NSString *const CQChatOrderingControllerDidChangeOrderingNotification = @"CQChatOrderingControllerDidChangeOrderingNotification";

typedef BOOL (^CQMatchingResult)(id <CQChatViewController> chatViewController);

static NSComparisonResult sortControllersAscending(id controller1, id controller2, void *context) {
	if ([controller1 isKindOfClass:[CQDirectChatController class]] && [controller2 isKindOfClass:[CQDirectChatController class]]) {
		CQDirectChatController *chatController1 = controller1;
		CQDirectChatController *chatController2 = controller2;

		NSDate *(^mostRecentActivityTimestampForChatController)(CQDirectChatController *) = ^NSDate *(CQDirectChatController *chatController) {
			if (chatController.mostRecentOutgoingMessageTimestamp && chatController1.mostRecentIncomingMessageTimestamp)
				return [chatController.mostRecentOutgoingMessageTimestamp laterDate:chatController.mostRecentIncomingMessageTimestamp];
			else if (chatController.mostRecentOutgoingMessageTimestamp) return chatController.mostRecentOutgoingMessageTimestamp;
			else if (chatController.mostRecentIncomingMessageTimestamp) return chatController.mostRecentIncomingMessageTimestamp;
			return nil;
		};

		NSComparisonResult (^comparisonResultForChatControllerDates)(NSDate *, NSDate *) = ^NSComparisonResult(NSDate *date1, NSDate *date2) {
			if (date1 && date2) {
				NSComparisonResult result = [date1 compare:date2];
				if (result == NSOrderedAscending) return NSOrderedDescending;
				if (result == NSOrderedDescending) return NSOrderedAscending;
				return NSOrderedSame;
			}
			if (date1) return NSOrderedDescending;
			if (date2) return NSOrderedAscending;
			return NSOrderedSame;
		};

		NSComparisonResult result = NSOrderedSame;
		if ([roomOrdering isEqualToString:@"recent-activity"]) {
			NSDate *mostRecentActivityTimestampForChatController1 = mostRecentActivityTimestampForChatController(chatController1);
			NSDate *mostRecentActivityTimestampForChatController2 = mostRecentActivityTimestampForChatController(chatController2);
			result = comparisonResultForChatControllerDates(mostRecentActivityTimestampForChatController1, mostRecentActivityTimestampForChatController2);
		} else if ([roomOrdering isEqualToString:@"recent-incoming-activity"])
			result = comparisonResultForChatControllerDates(chatController1.mostRecentIncomingMessageTimestamp, chatController1.mostRecentOutgoingMessageTimestamp);
		else if ([roomOrdering isEqualToString:@"recent-outgoing-activity"])
			result = comparisonResultForChatControllerDates(chatController1.mostRecentOutgoingMessageTimestamp, chatController1.mostRecentOutgoingMessageTimestamp);

		if (result == NSOrderedSame) // [roomOrdering isEqualToString:@"alphabetic"]
			result = [chatController1.connection.displayName caseInsensitiveCompare:chatController2.connection.displayName];

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

@implementation CQChatOrderingController {
	NSArray <id <CQChatViewController>> *_chatControllers;
	dispatch_queue_t _orderingQueue;
}

@synthesize chatViewControllers = _chatControllers;

+ (void) userDefaultsChanged {
	if (![NSThread isMainThread])
		return;

	roomOrdering = [[CQSettingsController settingsController] objectForKey:@"CQChatRoomSortOrder"];
}

+ (CQChatOrderingController *) defaultController {
	static BOOL creatingSharedInstance = NO;
	static CQChatOrderingController *sharedInstance = nil;

	if (!sharedInstance && !creatingSharedInstance) {
		creatingSharedInstance = YES;
		sharedInstance = [[self alloc] init];
	}

	return sharedInstance;
}

- (instancetype) init {
	if (!(self = [super init]))
		return nil;

	_orderingQueue = dispatch_queue_create("info.colloquy.orderingQueue", DISPATCH_QUEUE_SERIAL);
	_chatControllers = @[];

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_asyncSortChatControllers) name:CQChatViewControllerHandledMessageNotification object:nil];

	return self;
}

#pragma mark -

- (void) _asyncSortChatControllers {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_sortChatControllers) object:nil];
	[self performSelector:@selector(_sortChatControllers) withObject:nil afterDelay:0.];
}


- (void) _sortChatControllers {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_sortChatControllers) object:nil];
	dispatch_sync(_orderingQueue, ^{
		_chatControllers = [[_chatControllers copy] sortedArrayUsingFunction:sortControllersAscending context:NULL];
	});
	[[NSNotificationCenter chatCenter] postNotificationName:CQChatOrderingControllerDidChangeOrderingNotification object:nil];
}

- (NSUInteger) indexOfViewController:(id <CQChatViewController>) controller {
	__block NSUInteger index = NSNotFound;
	dispatch_sync(_orderingQueue, ^{
		index = [_chatControllers indexOfObjectIdenticalTo:controller];
	});
	return index;
}

- (void) _addViewController:(id <CQChatViewController>) controller resortingRightAway:(BOOL) resortingRightAway {
	dispatch_sync(_orderingQueue, ^{
		_chatControllers = [_chatControllers arrayByAddingObject:controller];
	});

	NSDictionary *notificationInfo = @{@"controller": controller};
	[[NSNotificationCenter chatCenter] postNotificationName:CQChatControllerAddedChatViewControllerNotification object:self userInfo:notificationInfo];

	if (resortingRightAway)
		[self _sortChatControllers];
}

- (void) addViewController:(id <CQChatViewController>) controller {
	[self _addViewController:controller resortingRightAway:YES];
}

- (void) addViewControllers:(NSArray <id <CQChatViewController>> *) controllers {
	for (id <CQChatViewController> controller in controllers) {
		NSAssert([controller conformsToProtocol:@protocol(CQChatViewController)], @"Cannot add chat view controller that does not conform to CQChatViewController");
		[self _addViewController:controller resortingRightAway:NO];
	}

	[self _sortChatControllers];
}

- (void) removeViewController:(id <CQChatViewController>) controller {
	dispatch_sync(_orderingQueue, ^{
		NSMutableArray *copy = [_chatControllers mutableCopy];
		NSUInteger index = [copy indexOfObjectIdenticalTo:controller];
		if (index != NSNotFound) {
			[copy removeObjectAtIndex:index];

			_chatControllers = [copy copy];
		}
	});
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

	__block CQConsoleController *consoleController = nil;

	dispatch_sync(_orderingQueue, ^{
		for (id <CQChatViewController> controller in _chatControllers) {
			if ([controller isMemberOfClass:[CQConsoleController class]] && controller.target == connection) {
				consoleController = (CQConsoleController *)controller;
				break;
			}
		}
	});

	if (consoleController)
		return consoleController;

	if (!exists) {
		if ((consoleController = [[CQConsoleController alloc] initWithTarget:connection])) {
			[[CQChatOrderingController defaultController] addViewController:consoleController];
		}
	}

	return consoleController;
}

- (NSArray <id <CQChatViewController>> *) chatViewControllersForConnection:(MVChatConnection *) connection {
	NSParameterAssert(connection != nil);

	NSMutableArray <id <CQChatViewController>> *result = [NSMutableArray array];

	dispatch_sync(_orderingQueue, ^{
		for (id controller in _chatControllers)
			if ([controller conformsToProtocol:@protocol(CQChatViewController)] && ((id <CQChatViewController>) controller).connection == connection)
				[result addObject:controller];
	});

	return result;
}

- (NSArray <id <CQChatViewController>> *) chatViewControllersOfClass:(Class) class {
	NSParameterAssert(class != NULL);

	NSMutableArray <id <CQChatViewController>> *result = [NSMutableArray array];

	dispatch_sync(_orderingQueue, ^{
		for (id controller in _chatControllers)
			if ([controller isMemberOfClass:class])
				[result addObject:controller];
	});

	return result;
}

- (NSArray <id <CQChatViewController>> *) chatViewControllersKindOfClass:(Class) class {
	NSParameterAssert(class != NULL);

	NSMutableArray <id <CQChatViewController>> *result = [NSMutableArray array];

	dispatch_sync(_orderingQueue, ^{
		for (id controller in _chatControllers)
			if ([controller isKindOfClass:class])
				[result addObject:controller];
	});

	return result;
}

#pragma mark -

- (CQChatRoomController *) chatViewControllerForRoom:(MVChatRoom *) room ifExists:(BOOL) exists {
	NSParameterAssert(room != nil);

	__block CQChatRoomController *chatRoomController = nil;

	dispatch_sync(_orderingQueue, ^{
		for (id <CQChatViewController> controller in _chatControllers) {
			if ([controller isMemberOfClass:[CQChatRoomController class]] && controller.target == room) {
				chatRoomController = (CQChatRoomController *)controller;
				break;
			}
		}
	});

	if (chatRoomController)
		return chatRoomController;

	if (!exists) {
		if ((chatRoomController = [[CQChatRoomController alloc] initWithTarget:room])) {
			[[CQChatOrderingController defaultController] addViewController:chatRoomController];

			if (room.connection == [CQChatController defaultController].nextRoomConnection)
				[[CQChatController defaultController] showChatController:chatRoomController animated:YES];
		}
	}

	return chatRoomController;
}

- (CQDirectChatController *) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists {
	return [self chatViewControllerForUser:user ifExists:exists userInitiated:YES];
}

- (CQDirectChatController *) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists userInitiated:(BOOL) initiated {
	NSParameterAssert(user != nil);

	__block CQDirectChatController *chatController = nil;

	dispatch_sync(_orderingQueue, ^{
		for (id <CQChatViewController> controller in _chatControllers) {
			if ([controller isMemberOfClass:[CQDirectChatController class]] && [controller.target isEqual:user]) {
				chatController = (CQDirectChatController *)controller;
				break;
			}
		}
	});

	if (chatController)
		return chatController;

	if (!exists) {
		if ((chatController = [[CQDirectChatController alloc] initWithTarget:user])) {
			[[CQChatOrderingController defaultController] addViewController:chatController];
		}
	}

	return chatController;
}

- (CQDirectChatController *) chatViewControllerForDirectChatConnection:(MVDirectChatConnection *) connection ifExists:(BOOL) exists {
	NSParameterAssert(connection != nil);

	__block CQDirectChatController *chatController = nil;

	dispatch_sync(_orderingQueue, ^{
		for (id <CQChatViewController> controller in _chatControllers) {
			if ([controller isMemberOfClass:[CQDirectChatController class]] && controller.target == connection) {
				chatController = (CQDirectChatController *)controller;
				break;
			}
		}
	});

	if (chatController)
		return chatController;

	if (!exists) {
		if ((chatController = [[CQDirectChatController alloc] initWithTarget:connection])) {
			[[CQChatOrderingController defaultController] addViewController:chatController];
		}
	}

	return chatController;
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
	__block id <CQChatViewController> result = nil;

	dispatch_sync(_orderingQueue, ^{
		if (_chatControllers.count < 2)
			result = [_chatControllers lastObject];
	});

	if (result)
		return result;

	__block NSUInteger index = NSNotFound;
	dispatch_sync(_orderingQueue, ^{
		index = [_chatControllers indexOfObject:chatViewController];
	});

	__block NSArray <id <CQChatViewController>> *firstHalf = nil;
	__block NSArray <id <CQChatViewController>> *secondHalf = nil;

	dispatch_sync(_orderingQueue, ^{
		if (options & NSEnumerationReverse) {
			firstHalf = [_chatControllers subarrayWithRange:NSMakeRange(0, index)];
			secondHalf = [_chatControllers subarrayWithRange:NSMakeRange((index + 1), (_chatControllers.count - (index + 1)))];
		} else {
			firstHalf = [_chatControllers subarrayWithRange:NSMakeRange((index + 1), (_chatControllers.count - (index + 1)))];
			secondHalf = [_chatControllers subarrayWithRange:NSMakeRange(0, index)];
		}
	});

	id <CQChatViewController> (^findNearestMatchForBlock)(CQMatchingResult) = ^(CQMatchingResult block) {
		__block id <CQChatViewController> nearestChatViewController = nil;
		[firstHalf enumerateObjectsWithOptions:options usingBlock:^(id object, NSUInteger firstHalfIndex, BOOL *stop) {
			if (block(object)) {
				nearestChatViewController = object;

				*stop = YES;
			}
		}];

		if (!nearestChatViewController) {
			[secondHalf enumerateObjectsWithOptions:options usingBlock:^(id object, NSUInteger secondHalfIndex, BOOL *stop) {
				if (block(object)) {
					nearestChatViewController = object;

					*stop = YES;
				}
			}];
		}

		return chatViewController;
	};

	if (requiringActivity && requiringHighlight) {
		return findNearestMatchForBlock(^BOOL(id <CQChatViewController> nearestChatViewController) {
			return nearestChatViewController.unreadCount && nearestChatViewController.importantUnreadCount;
		});
	}

	if (requiringHighlight) {
		return findNearestMatchForBlock(^BOOL(id <CQChatViewController> nearestChatViewController) {
			return nearestChatViewController.importantUnreadCount;
		});
	}

	if (requiringActivity) {
		return findNearestMatchForBlock(^BOOL(id <CQChatViewController> nearestChatViewController) {
			return nearestChatViewController.unreadCount;
		});
	}
	
	return nil;
}

- (id <CQChatViewController>) chatViewControllerPreceedingChatController:(id <CQChatViewController>) chatViewController requiringActivity:(BOOL) requiringActivity requiringHighlight:(BOOL) requiringHighlight {
	__block id <CQChatViewController> result = nil;

	dispatch_sync(_orderingQueue, ^{
		if (!_chatControllers.count)
			result = nil;

		if (!requiringActivity && !requiringHighlight) {
			NSUInteger index = [_chatControllers indexOfObjectIdenticalTo:chatViewController];
			if (!index)
				result = [_chatControllers lastObject];
			result = _chatControllers[(index - 1)];
		}
	});

	if (result)
		return result;

	return [self _enumerateChatViewControllersFromChatController:chatViewController withOption:NSEnumerationReverse requiringActivity:requiringActivity requiringHighlight:requiringHighlight];
}

- (id <CQChatViewController>) chatViewControllerFollowingChatController:(id <CQChatViewController>) chatViewController requiringActivity:(BOOL) requiringActivity requiringHighlight:(BOOL) requiringHighlight {
	__block id <CQChatViewController> result = nil;

	dispatch_sync(_orderingQueue, ^{
		if (!requiringActivity && !requiringHighlight) {
			NSUInteger index = [_chatControllers indexOfObjectIdenticalTo:chatViewController];
			if (index == (_chatControllers.count - 1))
				result = _chatControllers[0];
			result = _chatControllers[(index + 1)];
		}
	});

	if (result)
		return result;

	return [self _enumerateChatViewControllersFromChatController:chatViewController withOption:0 requiringActivity:requiringActivity requiringHighlight:requiringHighlight];
}

#pragma mark -

- (NSArray <MVChatConnection *> *) orderedConnections {
	NSArray <CQBouncerSettings *> *bouncers = [CQConnectionsController defaultController].bouncers;
	NSMutableArray <MVChatConnection *> *allConnections = [bouncers mutableCopy];
	for (CQBouncerSettings *settings in bouncers) {
		NSArray <MVChatConnection *> *connections = [[CQConnectionsController defaultController] bouncerChatConnectionsForIdentifier:settings.identifier];
		[allConnections addObjectsFromArray:connections];
	}

	NSArray <MVChatConnection *> *connections = [CQConnectionsController defaultController].directConnections;
	[allConnections addObjectsFromArray:connections];
	return [allConnections copy];
}

- (id) connectionAtIndex:(NSInteger) index {
	@synchronized([CQConnectionsController defaultController]) {
		NSArray <MVChatConnection *> *orderedConnections = self.orderedConnections;
		if (index >= (NSInteger)orderedConnections.count || index == NSNotFound)
			return nil;
		return orderedConnections[index];
	}
}

- (NSUInteger) sectionIndexForConnection:(id) connection {
	__block NSUInteger sectionIndex = -1;
	[self.orderedConnections enumerateObjectsUsingBlock:^(id object, NSUInteger objectIndex, BOOL *stop) {
		if (object == connection) {
			sectionIndex = objectIndex;
			*stop = YES;
		}
	}];

	return sectionIndex;
}

@end

NS_ASSUME_NONNULL_END
