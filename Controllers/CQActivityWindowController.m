#import "CQActivityWindowController.h"

#import "MVConnectionsController.h"

#import "CQTitleCell.h"
#import "CQGroupCell.h"

#define CQFileTransferInactiveWaitLimit 300 // in seconds
#define CQExpandCollapseRowInterval .5

NSString *CQActivityTypeFileTransfer = @"CQActivityTypeFileTransfer";
NSString *CQActivityTypeChatInvite = @"CQActivityTypeChatInvite";
NSString *CQActivityTypeDirectChatInvite = @"CQActivityTypeDirectChatInvite";

NSString *CQActivityStatusPending = @"CQActivityStatusPending";
NSString *CQActivityStatusAccepted = @"CQActivityStatusAccepted";
NSString *CQActivityStatusRejected = @"CQActivityStatusRejected";

NSString *CQDirectChatConnectionKey = @"CQDirectChatConnectionKey";

@interface CQActivityWindowController (Private)
- (NSUInteger) _fileTransferCountForConnection:(MVChatConnection *) connection;
- (NSUInteger) _directChatConnectionCount;
- (NSUInteger) _invitationCountForConnection:(MVChatConnection *) connection;

- (BOOL) _isHeaderItem:(id) item;
- (BOOL) _shouldExpandOrCollapse;

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
	sharedActivityWindowController = [[CQActivityWindowController alloc] init];

	return sharedActivityWindowController;
}

- (id) init {
	if (!(self = [super initWithWindowNibName:@"CQActivityWindow"]))
		return nil;

	_activity = [[NSMapTable alloc] initWithKeyOptions:NSMapTableZeroingWeakMemory valueOptions:NSMapTableStrongMemory capacity:[[MVConnectionsController defaultController] connections].count];
	[_activity setObject:[NSMutableArray array] forKey:CQDirectChatConnectionKey];

	_timeFormatter = [[NSDateFormatter alloc] init];
	_timeFormatter.dateStyle = NSDateFormatterNoStyle;
	_timeFormatter.timeStyle = NSDateFormatterShortStyle;

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
	[_titleCell release];
	[_groupCell release];
	[_activity release];
	[_timeFormatter release];

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
	MVChatConnection *connection = notification.object;

	[_activity setObject:[NSMutableArray array] forKey:connection];
}

- (void) connectionDidDisconnect:(NSNotification *) notification {
	MVChatConnection *connection = notification.object;

	[_outlineView reloadItem:connection reloadChildren:YES];
}

#pragma mark -

- (void) chatRoomInvitationAccepted:(NSNotification *) notification {
	MVChatRoom *room = notification.object;

	for (NSMutableDictionary *dictionary in [_activity objectForKey:room.connection]) {
		if ([dictionary objectForKey:@"type"] != CQActivityTypeChatInvite)
			continue;

		MVChatRoom *activityRoom = [dictionary objectForKey:@"room"];
		if (![room isEqualToChatRoom:activityRoom]) // can we just use == here?
			continue;

		[dictionary setObject:CQActivityStatusAccepted forKey:@"status"];

		[_outlineView reloadItem:dictionary];

		break;
	}
}

- (void) chatRoomInvitationReceived:(NSNotification *) notification {
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"JVAutoJoinChatRoomOnInvite"])
		return;

	NSString *name = [notification.userInfo objectForKey:@"room"];
	MVChatConnection *connection = notification.object;
	for (NSDictionary *dictionary in [_activity objectForKey:connection]) // if we already have an invite and its pending, ignore it
		if ([[dictionary objectForKey:@"room"] isCaseInsensitiveEqualToString:name]) // will @"room"'s value always be a string?
			if ([dictionary objectForKey:@"status"] == CQActivityStatusPending)
				return;

	NSMutableDictionary *chatRoomInfo = [notification.userInfo mutableCopy];
	[chatRoomInfo setObject:CQActivityTypeChatInvite forKey:@"type"];
	[chatRoomInfo setObject:CQActivityStatusPending forKey:@"status"];
	[chatRoomInfo setObject:connection forKey:@"connection"];
	[chatRoomInfo setObject:[NSDate date] forKey:@"date"];
	[self _appendActivity:chatRoomInfo forConnection:connection];
	[chatRoomInfo release];

	[_outlineView reloadData];

	[self orderFrontIfNecessary];
}

#pragma mark -

- (void) directChatDidConnect:(NSNotification *) notification {
	MVDirectChatConnection *connection = notification.object;

	for (NSDictionary *dictionary in [_activity objectForKey:CQDirectChatConnectionKey]) {
		if ([dictionary objectForKey:@"connection"] != connection)
			continue;

		[_outlineView reloadItem:dictionary];

		break;
	}
}

- (void) directChatErrorOccurred:(NSNotification *) notification {
	MVDirectChatConnection *connection = notification.object;

	for (NSDictionary *dictionary in [_activity objectForKey:CQDirectChatConnectionKey]) {
		if ([dictionary objectForKey:@"connection"] != connection)
			continue;

		[_outlineView reloadItem:dictionary];

		break;
	}
}

- (void) directChatOfferReceived:(NSNotification *) notification {
	MVDirectChatConnection *connection = notification.object;

	NSMutableDictionary *chatRoomInfo = [notification.userInfo mutableCopy];
	[chatRoomInfo setObject:CQActivityTypeDirectChatInvite forKey:@"type"];
	[chatRoomInfo setObject:connection forKey:@"connection"];
	[self _appendActivity:chatRoomInfo forConnection:CQDirectChatConnectionKey];
	[chatRoomInfo release];

	[_outlineView reloadData];

	[self orderFrontIfNecessary];
}

#pragma mark -

- (void) fileTransferDidStart:(NSNotification *) notification {
	MVFileTransfer *transfer = notification.object;

	for (NSDictionary *dictionary in [_activity objectForKey:transfer.user.connection]) {
		if ([dictionary objectForKey:@"transfer"] != transfer)
			continue;

		[_outlineView reloadItem:dictionary];

		break;
	}

	[self orderFrontIfNecessary];
}

- (void) fileTransferDidFinish:(NSNotification *) notification {
	MVFileTransfer *transfer = notification.object;
	for (NSDictionary *dictionary in [_activity objectForKey:transfer.user.connection]) {
		if ([dictionary objectForKey:@"transfer"] != transfer)
			continue;

		[_outlineView reloadItem:dictionary];
		
		break;
	}
	
	[self orderFrontIfNecessary];
}

- (void) fileTransferErrorReceived:(NSNotification *) notification {
	MVFileTransfer *transfer = notification.object;
	for (NSDictionary *dictionary in [_activity objectForKey:transfer.user.connection]) {
		if ([dictionary objectForKey:@"transfer"] != transfer)
			continue;

		[_outlineView reloadItem:dictionary];

		break;
	}

	[self orderFrontIfNecessary];
}

- (void) fileTransferWasOffered:(NSNotification *) notification {
	MVFileTransfer *transfer = notification.object;

	NSMutableDictionary *fileTransferInfo = [[NSMutableDictionary dictionaryWithObjectsAndKeys:CQActivityTypeFileTransfer, @"type", transfer, @"transfer", nil] mutableCopy];
	[fileTransferInfo setObject:CQActivityTypeFileTransfer forKey:@"type"];
	[self _appendActivity:fileTransferInfo forConnection:transfer.user.connection];
	[fileTransferInfo release];

	[_outlineView reloadData];

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
			if (childAtIndex == count)
				return key;
			count++;
		}
	}

	return [[_activity objectForKey:item] objectAtIndex:childAtIndex];
}

- (BOOL) outlineView:(NSOutlineView *) outlineView isItemExpandable:(id) item {
	return [self _isHeaderItem:item]; // top level, shows the connection name
}

- (NSInteger) outlineView:(NSOutlineView *) outlineView numberOfChildrenOfItem:(id) item {
	if (!item) {
		NSUInteger count = 0;
		for (id key in _activity)
			if (((NSArray *)[_activity objectForKey:key]).count)
				count++;
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

- (BOOL) outlineView:(NSOutlineView *) outlineView isGroupItem:(id) item {
	return [self _isHeaderItem:item]; // top level, shows the connection name
}

#pragma mark -

- (NSCell *) outlineView:(NSOutlineView *) outlineView dataCellForTableColumn:(NSTableColumn *) tableColumn item:(id) item {
	if ([item isKindOfClass:[MVChatConnection class]] || item == CQDirectChatConnectionKey) {
		if (!_groupCell)
			_groupCell = [[CQGroupCell alloc] initTextCell:@""];
		return _groupCell;
	}

	NSString *type = [item objectForKey:@"type"];
	if (type == CQActivityTypeChatInvite || type == CQActivityTypeDirectChatInvite) {
		if (!_titleCell)
			_titleCell = [[CQTitleCell alloc] init];
		return _titleCell;
	}

	return nil;
}

- (CGFloat) outlineView:(NSOutlineView *) outlineView heightOfRowByItem:(id) item {
	return (item && [self _isHeaderItem:item]) ? 19. : 40.;
}

- (BOOL) outlineView:(NSOutlineView *) outlineView shouldCollapseItem:(id) item {
	return [self _shouldExpandOrCollapse];
}

- (BOOL) outlineView:(NSOutlineView *) outlineView shouldEditTableColumn:(NSTableColumn *) tableColumn item:(id) item {
	return NO;
}

- (BOOL) outlineView:(NSOutlineView *) outlineView shouldExpandItem:(id) item {
	return [self _shouldExpandOrCollapse];
}

- (BOOL) outlineView:(NSOutlineView *) outlineView shouldSelectItem:(id) item {
	return ![self _isHeaderItem:item];
}

- (NSString *) outlineView:(NSOutlineView *) outlineView toolTipForCell:(NSCell *) cell rect:(NSRectPointer) rect tableColumn:(NSTableColumn *) tableColumn item:(id) item mouseLocation:(NSPoint) mouseLocation {
	if ([item isKindOfClass:[MVChatConnection class]]) {
		NSUInteger invites = [self _invitationCountForConnection:item];
		NSUInteger fileTransfers = [self _fileTransferCountForConnection:item];
		if (invites) {
			if (invites > 1) {
				if (fileTransfers) {
					if (fileTransfers > 1)
						return [NSString stringWithFormat:NSLocalizedString(@"%ld file transfers and %ld chat room invites on %@", @"tooltip"), fileTransfers, invites, ((MVChatConnection *)item).server];
					return [NSString stringWithFormat:NSLocalizedString(@"1 file transfer and %ld chat room invites on %@", @"tooltip"), invites, ((MVChatConnection *)item).server];
				}
				return [NSString stringWithFormat:NSLocalizedString(@"%ld chat room invites on %@", @"tooltip"), fileTransfers, ((MVChatConnection *)item).server];
			}
			if (fileTransfers) {
				if (fileTransfers > 1)
					return [NSString stringWithFormat:NSLocalizedString(@"%ld file transfers and 1 chat room invite on %@", @"tooltip"), fileTransfers, ((MVChatConnection *)item).server];
				return [NSString stringWithFormat:NSLocalizedString(@"1 file transfer and 1 chat room invite on %@", @"tooltip"), fileTransfers, ((MVChatConnection *)item).server];
			}
			return [NSString stringWithFormat:NSLocalizedString(@"1 chat room invite on %@", @"tooltip"), fileTransfers, ((MVChatConnection *)item).server];
		}
		if (fileTransfers) {
			if (fileTransfers > 1)
				return [NSString stringWithFormat:NSLocalizedString(@"%ld file transfers on %@", @"tooltip"), fileTransfers, ((MVChatConnection *)item).server];
			return [NSString stringWithFormat:NSLocalizedString(@"1 file transfer on %@", @"tooltip"), fileTransfers, ((MVChatConnection *)item).server];
		}
	}
	if (item == CQDirectChatConnectionKey) {
		NSUInteger count = [self _directChatConnectionCount];
		if (count > 1)
			return [NSString stringWithFormat:NSLocalizedString(@"%ld direct chat invitations", @"tooltip"), count];
		return [NSString stringWithFormat:NSLocalizedString(@"1 direct chat invitation", @"tooltip"), count];
	}
	return nil;
}

- (void) outlineView:(NSOutlineView *) outlineView willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) tableColumn item:(id) item {
	if ([cell isKindOfClass:[CQGroupCell class]]) {
		CQGroupCell *groupCell = (CQGroupCell *)cell;
		if (item == CQDirectChatConnectionKey)
			groupCell.title = NSLocalizedString(@"Direct Chat Invites", @"Direct Chat Invites header title");
		else groupCell.title = ((MVChatConnection *)item).server;
		groupCell.unansweredActivityCount = [outlineView isItemExpanded:item] ? 0 : ((NSArray *)[_activity objectForKey:item]).count;

		return;
	}

	CQTitleCell *titleCell = (CQTitleCell *)cell;
	titleCell.leftButtonCell.target = self;
	titleCell.rightButtonCell.target = self;

	NSString *title = nil;
	NSString *subtitle = nil;
	BOOL hidesLeftButton = NO;

	NSString *titleFormat = nil;

	NSString *type = [item objectForKey:@"type"];
	MVChatUser *user = [item objectForKey:@"user"];
	NSDate *date = [item objectForKey:@"date"];
	if (type == CQActivityTypeChatInvite) {
		NSString *status = [item objectForKey:@"status"];
		if (status == CQActivityStatusAccepted) {
			titleFormat = NSLocalizedString(@"Joined %@ on %@", @"cell label text format");
			// subtitle: @"lastMessageHere";

			titleCell.leftButtonCell.action = @selector(showChatPanel:); // magnifying glass
			titleCell.rightButtonCell.action = @selector(removeRowFromWindow:); // x
		} else if (status == CQActivityStatusPending) {
			titleFormat = NSLocalizedString(@"Invited to %@ on %@", @"cell label text format");
			subtitle = [[NSString alloc] initWithFormat:NSLocalizedString(@"By %@ at %@", @"by (user) at (time) cell label subtitle text"), user.nickname, [_timeFormatter stringFromDate:date]];

			titleCell.leftButtonCell.action = @selector(acceptChatInvite:); // check
			titleCell.rightButtonCell.action = @selector(rejectChatInvite:); // x
		} else if (status == CQActivityStatusRejected) {
			titleFormat = NSLocalizedString(@"Ignored invite to %@ on %@", @"Ignored invite to (room) on (server) cell label text format");
			subtitle = [[NSString alloc] initWithFormat:NSLocalizedString(@"Invited by %@ at %@", @"by (user) at (time) cell label subtitle text"), user.nickname, [_timeFormatter stringFromDate:date]];

			titleCell.leftButtonCell.action = @selector(requestChatInvite:); // retry circle, /knock's
			titleCell.rightButtonCell.action = @selector(removeRowFromWindow:); // x
		}

		title = [[NSString alloc] initWithFormat:titleFormat, [item objectForKey:@"room"], ((MVChatConnection *)[item objectForKey:@"connection"]).server];
	}

	if (type == CQActivityTypeDirectChatInvite) {
		MVDirectChatConnection *connection = [item objectForKey:@"connection"];
		switch (connection.status) {
		case MVDirectChatConnectionConnectedStatus:
			titleFormat = NSLocalizedString(@"Accepted direct chat with %@", @"cell label text format"); // left: show, right: close
			// subtitle: show last chat line

			titleCell.leftButtonCell.action = @selector(showChatPanel:); // magnifying glass
			titleCell.rightButtonCell.action = @selector(removeRowFromWindow:); // x
			break;
		case MVDirectChatConnectionWaitingStatus:
			titleFormat = NSLocalizedString(@"Direct chat request from %@", @"cell label text format"); // left: accept, right: reject
			// show shared chat rooms

			titleCell.leftButtonCell.action = @selector(acceptChatInvite:); // check
			titleCell.rightButtonCell.action = @selector(rejectChatInvite:); // x
			break;
		case MVDirectChatConnectionDisconnectedStatus:
			hidesLeftButton = YES; // right: close/remove
			titleFormat = NSLocalizedString(@"Ended direct chat with %@", @"cell label text format");
			// show last chat line

			titleCell.leftButtonCell.action = @selector(showChatPanel:); // magnifying glass
			titleCell.rightButtonCell.action = @selector(removeRowFromWindow:); // x
			break;
		case MVDirectChatConnectionErrorStatus:
			titleFormat = NSLocalizedString(@"Error during direct chat with %@", @"cell label text format");
			// show error reason

			titleCell.leftButtonCell.action = @selector(requestChatInvite:); // retry circle, new dcc chat session
			titleCell.rightButtonCell.action = @selector(removeRowFromWindow:); // x
			break;
		}

		title = [[NSString alloc] initWithFormat:titleFormat, connection.user.displayName];
	}

	if (type == CQActivityTypeFileTransfer) {
		// if its done or cancelled, only show one button
	}

	titleCell.hidesLeftButton = hidesLeftButton;

	titleCell.titleText = title;
	[title release];

	titleCell.subtitleText = subtitle;
	[subtitle release];
}

#pragma mark -

- (void) showChatPanel:(id) sender {
	
}

- (void) removeRowFromWindow:(id) sender {
	
}

- (void) acceptChatInvite:(id) sender {
	
}

- (void) rejectChatInvite:(id) sender {
	// set rejected date
}

- (void) requestChatInvite:(id) sender {
	
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

- (BOOL) _isHeaderItem:(id) item {
	return ([item isKindOfClass:[MVChatConnection class]] || item == CQDirectChatConnectionKey);
}

- (BOOL) _shouldExpandOrCollapse {
	if (!_rowLastClickedTime) {
		_rowLastClickedTime = [NSDate timeIntervalSinceReferenceDate];

		return YES;
	}

	NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
	BOOL shouldExpandOrCollapse = ((currentTime - _rowLastClickedTime) > CQExpandCollapseRowInterval);

	_rowLastClickedTime = currentTime;

	return shouldExpandOrCollapse;
}

#pragma mark -

- (void) _appendActivity:(NSDictionary *) activity forConnection:(id) connection {
	NSMutableArray *activities = [_activity objectForKey:connection];
	NSString *type = [activity objectForKey:@"type"];
	if (type == CQActivityTypeFileTransfer) // file transfers are sorted by time added, so just add to the end
		[activities addObject:activity];

	if (type == CQActivityTypeChatInvite) {
		NSUInteger insertionPoint = 0;
		for (NSDictionary *existingActivity in activities) {
			type = [existingActivity objectForKey:@"type"];
			if (type == CQActivityTypeFileTransfer) // File transfers are at the end and we want to insert above it
				break;

			if (type == CQActivityTypeChatInvite)
				continue;

			if ([[activity objectForKey:@"room"] compare:[existingActivity objectForKey:@"room"]] == NSOrderedDescending)
				insertionPoint++;
			else break;
		}

		[activities insertObject:activity atIndex:insertionPoint];
	}

	if (type == CQActivityTypeDirectChatInvite) {
		NSUInteger insertionPoint = 0;
		id newUser = [activity objectForKey:@"user"];
		for (NSDictionary *existingActivity in activities) {
			if ([newUser compare:[existingActivity objectForKey:@"user"]] != NSOrderedDescending) // multiple dcc chat sessions for the same username are valid, added to the end, after the current ones.
				insertionPoint++;
			else break;
		}

		[activities insertObject:activity atIndex:insertionPoint];
	}
}
@end
