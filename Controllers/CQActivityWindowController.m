#import "CQActivityWindowController.h"

#import "MVConnectionsController.h"
 
#define CQFileTransferInactiveWaitLimit 300 // in seconds

NSString *CQActivityTypeFileTransfer = @"CQActivityTypeFileTransfer";
NSString *CQActivityTypeChatInvite = @"CQActivityTypeChatInvite";
NSString *CQActivityTypeDirectChatInvite = @"CQActivityTypeDirectChatInvite";

NSString *CQDirectChatConnectionKey = @"CQDirectChatConnectionKey";

@interface CQActivityWindowController (Private)
- (NSUInteger) _fileTransferCountForConnection:(MVChatConnection *) connection;
- (NSUInteger) _directChatConnectionCount;
- (NSUInteger) _invitationCountForConnection:(MVChatConnection *) connection;

- (void) _appendActivity:(id) activity forConnection:(id) connection;
@end

#pragma mark -

@implementation CQActivityWindowController
+ (CQActivityWindowController *) sharedController {
	static CQActivityWindowController *sharedActivityWindowController = nil;
	static BOOL creatingSharedInstance = NO;
	if (sharedActivityWindowController)
		return sharedActivityWindowController;

	creatingSharedInstance = YES;
	sharedActivityWindowController = [[CQActivityWindowController alloc] initWithWindowNibName:nil];

	return sharedActivityWindowController;
}

- (id) initWithWindowNibName:(NSString *) windowNibName {
	if (!(self = [super initWithWindowNibName:@"CQActivityWindow"]))
		return nil;

	_activity = [[NSMapTable alloc] initWithKeyOptions:NSMapTableZeroingWeakMemory valueOptions:NSMapTableStrongMemory capacity:[[MVConnectionsController defaultController] connections].count];
	[_activity setObject:[NSMutableArray array] forKey:CQDirectChatConnectionKey];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(chatRoomInvitationAccepted:) name:MVChatRoomJoinedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(chatRoomInvitationReceived:) name:MVChatRoomInvitedNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(directChatDidConnect:) name:MVDirectChatConnectionErrorDomain object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(directChatErrorOccurred:) name:MVDirectChatConnectionDidConnectNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(directChatOfferReceived:) name:MVDirectChatConnectionOfferNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileTransferWasOffered:) name:MVDownloadFileTransferOfferNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileTransferDidStart:) name:MVFileTransferStartedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileTransferDidFinish:) name:MVFileTransferFinishedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileTransferErrorReceived:) name:MVFileTransferErrorOccurredNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionDidConnect:) name:MVChatConnectionDidConnectNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionDidDisconnect:) name:MVChatConnectionDidDisconnectNotification object:nil];

	return self;
}

- (void) dealloc {
	[_activity release];

	[super dealloc];
}

#pragma mark -

- (IBAction) showActivityWindow:(id) sender {
	[self.window makeKeyAndOrderFront:nil];
}

- (IBAction) hideActivityWindow:(id) sender {
	[self.window orderOut:nil];
}

- (void) orderFrontIfNecessary {
	if (![self.window isVisible])
		[self.window makeKeyAndOrderFront:nil];
}

#pragma mark -

- (void) connectionDidConnect:(NSNotification *) notification {
	if ([MVConnectionsController defaultController].connectedConnections.count > 2)
		return;

	MVChatConnection *connection = notification.object;

	[_activity setObject:[NSMutableArray array] forKey:connection];
}

- (void) connectionDidDisconnect:(NSNotification *) notification {
	MVChatConnection *connection = notification.object;

	for (NSMutableDictionary *dictionary in [_activity objectForKey:connection]) {
		// mark everything as inactive/invalid for the connection
	}

	[_outlineView reloadData];
}

#pragma mark -

- (void) chatRoomInvitationAccepted:(NSNotification *) notification {
	MVChatRoom *room = notification.object;
	if (![[MVConnectionsController defaultController] managesConnection:room.connection])
		  return;

	for (NSMutableDictionary *dictionary in [_activity objectForKey:room.connection]) {
		if ([dictionary objectForKey:@"type"] != CQActivityTypeChatInvite)
			continue;

		MVChatRoom *activityRoom = [dictionary objectForKey:@"room"];
		if (![room isEqualToChatRoom:activityRoom]) // can we just use == here?
			continue;

		// mark item as checked in the list

		[_outlineView reloadData];

		break;
	}
}

- (void) chatRoomInvitationReceived:(NSNotification *) notification {
	MVChatConnection *connection = notification.object;
	if (![[MVConnectionsController defaultController] managesConnection:connection])
		return;

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"JVAutoJoinChatRoomOnInvite"])
		return;

	// if we're already in the room, ignore it

	NSMutableDictionary *chatRoomInfo = [notification.userInfo mutableCopy];
	[chatRoomInfo setObject:CQActivityTypeChatInvite forKey:@"type"];
	[self _appendActivity:chatRoomInfo forConnection:connection];
	[chatRoomInfo release];

	[_outlineView reloadData];

	[self orderFrontIfNecessary];
}

#pragma mark -

- (void) directChatDidConnect:(NSNotification *) notification {
	// mark as accepted
}

- (void) directChatErrorOccurred:(NSNotification *) notification {
	// mark as error
}

- (void) directChatOfferReceived:(NSNotification *) notification {
	MVDirectChatConnection *connection = notification.object;

	NSMutableDictionary *chatRoomInfo = [notification.userInfo mutableCopy];
	[chatRoomInfo setObject:CQActivityTypeDirectChatInvite forKey:@"type"];
	[self _appendActivity:chatRoomInfo forConnection:connection];
	[chatRoomInfo release];

	[_outlineView reloadData];

	[self orderFrontIfNecessary];
}

#pragma mark -

- (void) fileTransferWasOffered:(NSNotification *) notification {
	MVFileTransfer *transfer = notification.object;

	NSMutableDictionary *fileTransferInfo = [[NSDictionary dictionaryWithObjectsAndKeys:CQActivityTypeFileTransfer, @"type", transfer, @"transfer", nil] mutableCopy];
	[fileTransferInfo setObject:CQActivityTypeFileTransfer forKey:@"type"];
	[self _appendActivity:fileTransferInfo forConnection:transfer.user.connection];
	[fileTransferInfo release];

	[self performSelector:@selector(_invalidateItemForFileTransfer:) withObject:transfer afterDelay:CQFileTransferInactiveWaitLimit];

	[_outlineView reloadData];

	[self orderFrontIfNecessary];
}

- (void) fileTransferDidStart:(NSNotification *) notification {
	MVFileTransfer *transfer = notification.object;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(invalidateFileTransfer:) object:transfer];

	// mark as started / start tracking progress

	[self orderFrontIfNecessary];
}

- (void) fileTransferDidFinish:(NSNotification *) notification {
	// mark as done

	[self orderFrontIfNecessary];
}

- (void) fileTransferErrorReceived:(NSNotification *) notification {
	// mark as invalid
	
	[self orderFrontIfNecessary];
}

#pragma mark -

- (id) outlineView:(NSOutlineView *) outlineView child:(NSInteger) childAtIndex ofItem:(id) item {
	if (!item) {
		NSInteger count = 0;
		for (id key in _activity) {
			NSArray *activity = [_activity objectForKey:key];
			if (!activity.count)
				continue;
			if (childAtIndex == count) {
				return key;
			}
			count++;
		}
	}

	return [[_activity objectForKey:item] objectAtIndex:childAtIndex];
}

- (BOOL) outlineView:(NSOutlineView *) outlineView isItemExpandable:(id) item {
	return ([item isKindOfClass:[MVChatConnection class]] || item == CQDirectChatConnectionKey); // top level, shows the connection name
}

- (NSInteger) outlineView:(NSOutlineView *) outlineView numberOfChildrenOfItem:(id) item {
	if (!item) {
		NSUInteger count = 0;
		for (id key in _activity) {
			NSArray *activity = [_activity objectForKey:key];
			if (activity.count)
				count++;
		}
		return count;
	}

	return ((NSArray *)[_activity objectForKey:item]).count;
}

- (id) outlineView:(NSOutlineView *) outlineView objectValueForTableColumn:(NSTableColumn *) tableColumn byItem:(id) item {
	if ([item isKindOfClass:[MVChatConnection class]])
		return ((MVChatConnection *)item).server;
	if (item == CQDirectChatConnectionKey)
		return NSLocalizedString(@"Direct Chat Invites", @"Direct Chat Invites header title");

	return [item description];
}

#pragma mark -

- (CGFloat) outlineView:(NSOutlineView *) outlineView heightOfRowByItem:(id) item {
	return ([self outlineView:outlineView isItemExpandable:item]) ? 22. : 50.;
}

- (NSCell *) outlineView:(NSOutlineView *) outlineView dataCellForTableColumn:(NSTableColumn *) tableColumn item:(id) item {
	NSString *text = nil;
	if ([item isKindOfClass:[MVChatConnection class]])
		text = ((MVChatConnection *)item).server;
	if (item == CQDirectChatConnectionKey)
		text = NSLocalizedString(@"Direct Chat Invites", @"Direct Chat Invites header title");
	if (!text.length)
		text = [item description];
	return [[[NSCell alloc] initTextCell:text] autorelease];
}

- (BOOL) outlineView:(NSOutlineView *) outlineView shouldEditTableColumn:(NSTableColumn *) tableColumn item:(id) item {
	return NO;
}

- (BOOL) outlineView:(NSOutlineView *) outlineView shouldSelectItem:(id) item {
	return ![self outlineView:outlineView isItemExpandable:item];
}

- (NSString *) outlineView:(NSOutlineView *) outlineView toolTipForCell:(NSCell *) cell rect:(NSRectPointer) rect tableColumn:(NSTableColumn *) tableColumn item:(id) item mouseLocation:(NSPoint) mouseLocation {
	if ([item isKindOfClass:[MVChatConnection class]]) {
		NSUInteger invites = [self _invitationCountForConnection:item];
		NSUInteger fileTransfers = [self _fileTransferCountForConnection:item];
		if (invites) {
			if (invites > 1) {
				if (fileTransfers) {
					if (fileTransfers > 1) {
						return [NSString stringWithFormat:@"%ld file transfers and %ld chat room invites on %@", fileTransfers, invites, ((MVChatConnection *)item).server];
					}
					return [NSString stringWithFormat:@"1 file transfer and %ld chat room invites on %@", invites, ((MVChatConnection *)item).server];
				}
				return [NSString stringWithFormat:@"%ld chat room invites on %@", fileTransfers, ((MVChatConnection *)item).server];
			}
			if (fileTransfers) {
				if (fileTransfers > 1) {
					return [NSString stringWithFormat:@"%ld file transfers and 1 chat room invite on %@", fileTransfers, ((MVChatConnection *)item).server];
				}
				return [NSString stringWithFormat:@"1 file transfer and 1 chat room invite on %@", fileTransfers, ((MVChatConnection *)item).server];
			}
			return [NSString stringWithFormat:@"1 chat room invite on %@", fileTransfers, ((MVChatConnection *)item).server];
		}
		if (fileTransfers) {
			if (fileTransfers > 1)
				return [NSString stringWithFormat:@"%ld file transfers on %@", fileTransfers, ((MVChatConnection *)item).server];
			return [NSString stringWithFormat:@"1 file transfer on %@", fileTransfers, ((MVChatConnection *)item).server];
		}
	}

	if (item == CQDirectChatConnectionKey) {
		NSUInteger count = [self _directChatConnectionCount];
		if (count > 1)
			return [NSString stringWithFormat:@"%ld direct chat invitations", count];
		return [NSString stringWithFormat:@"1 direct chat invitation", count];
	}

	return nil;
}

#pragma mark -

- (NSUInteger) _countForType:(NSString *) type inConnection:(id) connection {
	NSUInteger count = 0;
	for (NSDictionary *dictionary in [_activity objectForKey:connection])
		if ([dictionary objectForKey:@"type"] == type)
			count++;
	return count;
}

- (NSUInteger) _directChatConnectionCount {
	return [self _countForType:CQActivityTypeDirectChatInvite inConnection:CQDirectChatConnectionKey];
}

- (NSUInteger) _fileTransferCountForConnection:(MVChatConnection *) connection {
	return [self _countForType:CQActivityTypeFileTransfer inConnection:connection];
}

- (NSUInteger) _invitationCountForConnection:(MVChatConnection *) connection {
	return [self _countForType:CQActivityTypeChatInvite inConnection:connection];
}

#pragma mark -

- (void) _appendActivity:(NSDictionary *) activity forConnection:(id) connection {
	NSMutableArray *activities = [_activity objectForKey:connection];
	NSString *type = [activity objectForKey:@"type"];
	if (type == CQActivityTypeFileTransfer) { // file transfers are sorted by time added, so just add to the end
		[activities addObject:activity];
	}

	if (type == CQActivityTypeChatInvite) {
		NSUInteger insertionPoint = 0;
		for (NSDictionary *existingActivity in activities) {
			type = [existingActivity objectForKey:@"type"]
			if (type == CQActivityTypeFileTransfer) // File transfers are at the end.
				break;

			if (type == CQActivityTypeChatInvite)
				continue;

			id newRoom = [activity objectForKey:@"room"];
			id existingRoom = [existingActivity objectForKey:@"room"];
			NSComparisonResult comparisonResult = [newRoom compare:existingRoom];
			if (comparisonResult == NSOrderedSame /* and the existingActivity is still pending */) // don't show multiple invites for the same room
				return;

			if (comparisonResult == NSOrderedDescending)
				insertionPoint++;
			else break;
		}

		[activities insertObject:activity atIndex:insertionPoint];
	}

	if (type == CQActivityTypeDirectChatInvite) {
		NSUInteger insertionPoint = 0;
		id newUser = [activity objectForKey:@"user"];
		for (NSDictionary *existingActivity in activities) {
			id existingUser = [existingActivity objectForKey:@"user"];
			NSComparisonResult comparisonResult = [newUser compare:existingUser];
			if (comparisonResult != NSOrderedDescending) // multiple dcc chat sessions for the same username are valid, added to the end, after the current ones.
				insertionPoint++;
			else break;
		}

		[activities insertObject:activity atIndex:insertionPoint];
	}
}
@end
