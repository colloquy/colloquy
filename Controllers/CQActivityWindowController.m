#import "CQActivityWindowController.h"

#import "MVConnectionsController.h"
#import "MVFileTransfer.h"
#import "MVFileTransferController.h"
#import "JVChatController.h"

#import "CQDownloadCell.h"
#import "CQSubtitleCell.h"
#import "CQGroupCell.h"

#define CQFileTransferInactiveWaitLimit 300 // in seconds
#define CQExpandCollapseRowInterval .5

NSString *CQActivityTypeChatInvite = @"CQActivityTypeChatInvite";
NSString *CQActivityTypeDirectChatInvite = @"CQActivityTypeDirectChatInvite";
NSString *CQActivityTypeDirectDownload = @"CQActivityTypeDirectDownload";
NSString *CQActivityTypeFileTransfer = @"CQActivityTypeFileTransfer";

NSString *CQActivityStatusAccepted = @"CQActivityStatusAccepted";
NSString *CQActivityStatusError = @"CQActivityStatusError";
NSString *CQActivityStatusFinished = @"CQActivityStatusFinished";
NSString *CQActivityStatusPending = @"CQActivityStatusPending";
NSString *CQActivityStatusRejected = @"CQActivityStatusRejected";

NSString *CQDirectChatConnectionKey = @"CQDirectChatConnectionKey";
NSString *CQDirectDownloadKey = @"CQDirectDownloadKey";

NSString *MVPrettyFileSize (unsigned long long size) {
	NSString *ret = nil;
	if (size == 0.) ret = NSLocalizedString(@"Zero bytes", "no file size");
	else if (size > 0. && size < 1024.) ret = [NSString stringWithFormat:NSLocalizedString(@"%lu bytes", "file size measured in bytes"), size];
	else if (size >= 1024. && size < pow (1024., 2.)) ret = [NSString stringWithFormat:NSLocalizedString(@"%.1f KB", "file size measured in kilobytes"),  (size / 1024.)];
	else if (size >= pow (1024., 2.) && size < pow (1024., 3.)) ret = [NSString stringWithFormat:NSLocalizedString(@"%.2f MB", "file size measured in megabytes"),  (size / pow (1024., 2.))];
	else if (size >= pow (1024., 3.) && size < pow (1024., 4.)) ret = [NSString stringWithFormat:NSLocalizedString(@"%.3f GB", "file size measured in gigabytes"),  (size / pow (1024., 3.))];
	else if (size >= pow (1024., 4.)) ret = [NSString stringWithFormat:NSLocalizedString(@"%.4f TB", "file size measured in terabytes"),  (size / pow (1024., 4.))];
	return ret;
}

NSString *MVReadableTime (NSTimeInterval date, BOOL longFormat) {
	NSTimeInterval secs = [[NSDate date] timeIntervalSince1970] - date;
	NSUInteger i = 0, stop = 0;
	NSDictionary *desc = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"second", "singular second"), [NSNumber numberWithUnsignedLong:1], NSLocalizedString(@"minute", "singular minute"), [NSNumber numberWithUnsignedLong:60], NSLocalizedString(@"hour", "singular hour"), [NSNumber numberWithUnsignedLong:3600], NSLocalizedString(@"day", "singular day"), [NSNumber numberWithUnsignedLong:86400], NSLocalizedString(@"week", "singular week"), [NSNumber numberWithUnsignedLong:604800], NSLocalizedString(@"month", "singular month"), [NSNumber numberWithUnsignedLong:2628000], NSLocalizedString(@"year", "singular year"), [NSNumber numberWithUnsignedLong:31536000], nil];
	NSDictionary *plural = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"seconds", "plural seconds"), [NSNumber numberWithUnsignedLong:1], NSLocalizedString(@"minutes", "plural minutes"), [NSNumber numberWithUnsignedLong:60], NSLocalizedString(@"hours", "plural hours"), [NSNumber numberWithUnsignedLong:3600], NSLocalizedString(@"days", "plural days"), [NSNumber numberWithUnsignedLong:86400], NSLocalizedString(@"weeks", "plural weeks"), [NSNumber numberWithUnsignedLong:604800], NSLocalizedString(@"months", "plural months"), [NSNumber numberWithUnsignedLong:2628000], NSLocalizedString(@"years", "plural years"), [NSNumber numberWithUnsignedLong:31536000], nil];
	NSDictionary *use = nil;
	NSMutableArray *breaks = nil;
	NSUInteger val = 0.;
	NSString *retval = nil;

	if (secs < 0) secs *= -1;

	breaks = [[[desc allKeys] mutableCopy] autorelease];
	[breaks sortUsingSelector:@selector (compare:)];

	while (i < [breaks count] && secs >= [[breaks objectAtIndex:i] doubleValue]) i++;
	if (i > 0) i--;
	stop = [[breaks objectAtIndex:i] unsignedIntValue];

	val = (NSUInteger)  (secs / (float) stop);
	use =  (val > 1 ? plural :desc);
	retval = [NSString stringWithFormat:@"%u %@", val, [use objectForKey:[NSNumber numberWithUnsignedLong:stop]]];
	if (longFormat && i > 0) {
		NSUInteger rest = (NSUInteger)  ((NSUInteger) secs % stop);
		stop = [[breaks objectAtIndex:--i] unsignedIntValue];
		rest = (NSUInteger)  (rest / (float) stop);
		if (rest > 0) {
			use =  (rest > 1 ? plural :desc);
			retval = [retval stringByAppendingFormat:@" %u %@", rest, [use objectForKey:[breaks objectAtIndex:i]]];
		}
	}

	return retval;
}

@interface CQActivityWindowController (Private)
- (void) _setDestinationForTransfer:(MVFileTransfer *) transfer shouldAsk:(BOOL) shouldAsk;

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
	[_activity setObject:[NSMutableArray array] forKey:CQDirectDownloadKey];

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

	// The notification object is a string if we receive an invite in the first few seconds of Colloquy being open, work around that and make sure we have a MVChatConnection to work with instead.
	id connection = notification.object;
	if (![connection isKindOfClass:[MVChatConnection class]])
		connection = [[MVConnectionsController  defaultController] connectionForServerAddress:connection];

	if (!connection) {
		NSLog(@"Failed to find a connection for:%@. Unable to join room after invite.", notification.object);
		return;
	}

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

	[self orderFrontIfNecessary];
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

- (void) downloadDidFinish:(NSURLDownload *) download {
	for (NSMutableDictionary *dictionary in [_activity objectForKey:CQDirectDownloadKey]) {
		if ([dictionary objectForKey:@"controller"] != download)
			continue;

		[dictionary setObject:CQActivityStatusFinished forKey:@"status"];

		[[MVFileTransferController defaultController] fileAtPathDidFinish:[dictionary objectForKey:@"path"]];

		if ([[NSUserDefaults standardUserDefaults] integerForKey:@"JVRemoveTransferedItems"] == 2) {
			[[_activity objectForKey:CQDirectDownloadKey] removeObject:dictionary];

			[_outlineView reloadData];

			return;
		}

		[_outlineView reloadItem:dictionary];

		break;
	}
}

- (void) downloadFileAtURL:(NSURL *) url toLocalFile:(NSString *) path {
	WebDownload *download = [[WebDownload alloc] initWithRequest:[NSURLRequest requestWithURL:url] delegate:self];

	if (!download) {
		NSBeginAlertSheet(NSLocalizedString(@"Invalid URL", "Invalid URL title"), nil, nil, nil, self.window, nil, nil, nil, nil, NSLocalizedString(@"The download URL is either invalid or unsupported.", "Invalid URL message"));
		return;
	}

	if (path)
		[download setDestination:path allowOverwrite:NO];

	NSMutableDictionary *item = [[NSMutableDictionary alloc] init];
	[item setObject:[NSNumber numberWithUnsignedLongLong:0] forKey:@"transfered"];
	[item setObject:[NSNumber numberWithDouble:0.] forKey:@"rate"];
	[item setObject:[NSNumber numberWithUnsignedLongLong:0] forKey:@"size"];
	[item setObject:download forKey:@"controller"];
	[item setObject:url forKey:@"url"];
	[item setObject:CQActivityTypeDirectDownload forKey:@"type"];
	[item setObject:path.length ? path :url.path.lastPathComponent forKey:@"path"];

	[[_activity objectForKey:CQDirectDownloadKey] addObject:item];

	[item release];
	[download release];
}

- (void) downloadFileSavePanelDidEnd:(NSSavePanel *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	WebDownload *download = [(WebDownload *)contextInfo retain];

	if (returnCode == NSOKButton) {
		for (NSMutableDictionary *dictionary in [_activity objectForKey:CQDirectDownloadKey]) {
			if ([dictionary objectForKey:@"controller"] != download)
				continue;
			if (sheet)
				[dictionary setObject:[sheet filename] forKey:@"path"];

			[download setDestination:[dictionary objectForKey:@"path"] allowOverwrite:YES];

			break;
		}
	} else {
		[download cancel];

		for (NSMutableDictionary *dictionary in [_activity objectForKey:CQDirectDownloadKey]) {
			if ([dictionary objectForKey:@"controller"] != download)
				continue;

			[dictionary setObject:CQActivityStatusRejected forKey:@"status"];

			break;
		}
	}

	[download release];
}

- (NSWindow *) downloadWindowForAuthenticationSheet:(WebDownload *) download {
	return self.window;
}

- (void) download:(NSURLDownload *) download decideDestinationWithSuggestedFilename:(NSString *) filename {
	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"JVAskForTransferSaveLocation"]) {
		NSString *path = [[[self class] userPreferredDownloadFolder] stringByAppendingPathComponent:filename];

		for (NSMutableDictionary *info in [_activity objectForKey:CQDirectDownloadKey]) {
			if ([info objectForKey:@"controller"] != download)
				continue;

			[info setObject:path forKey:@"path"];

			break;
		}

		[self downloadFileSavePanelDidEnd:nil returnCode:NSOKButton contextInfo:download];
	} else {
		NSSavePanel *savePanel = [NSSavePanel savePanel];
		savePanel.nameFieldLabel = filename;
		[savePanel beginSheetForDirectory:[MVFileTransferController userPreferredDownloadFolder] file:filename modalForWindow:nil modalDelegate:self didEndSelector:@selector(downloadFileSavePanelDidEnd:returnCode:contextInfo:) contextInfo:download];
	}
}

- (void) download:(NSURLDownload *) download didFailWithError:(NSError *) error {
	for (NSMutableDictionary *dictionary in [_activity objectForKey:CQDirectDownloadKey]) {
		if ([dictionary objectForKey:@"controller"] != download)
			continue;

		[dictionary setObject:CQActivityStatusError forKey:@"status"];

		[_outlineView reloadItem:dictionary];

		break;
	}
}

- (void) download:(NSURLDownload *) download didReceiveDataOfLength:(NSUInteger) length {
	for (NSMutableDictionary *dictionary in [_activity objectForKey:CQDirectDownloadKey]) {
		if ([dictionary objectForKey:@"controller"] != download)
			continue;

		NSTimeInterval timeslice = [[dictionary objectForKey:@"started"] timeIntervalSinceNow] * -1;
		unsigned long long transfered = [[dictionary objectForKey:@"transfered"] unsignedLongLongValue] + length;

		[dictionary setObject:CQActivityStatusAccepted forKey:@"status"];
		[dictionary setObject:[NSNumber numberWithUnsignedLongLong:transfered] forKey:@"transfered"];

		unsigned long long size = [[dictionary objectForKey:@"size"] unsignedLongLongValue];
		if (transfered > size)
			[dictionary setObject:[NSNumber numberWithUnsignedLongLong:transfered] forKey:@"size"];

		if (transfered != size)
			[dictionary setObject:[NSNumber numberWithDouble:(transfered / timeslice)] forKey:@"rate"];

		if (![dictionary objectForKey:@"started"])
			[dictionary setObject:[NSDate date] forKey:@"started"];

		[_outlineView reloadItem:dictionary];

		break;
	}
}

- (void) download:(NSURLDownload *) download didReceiveResponse:(NSURLResponse *) response {
	for (NSMutableDictionary *dictionary in [_activity objectForKey:CQDirectDownloadKey]) {
		if ([dictionary objectForKey:@"controller"] != download)
			continue;

		[dictionary setObject:[NSNumber numberWithUnsignedLongLong:0] forKey:@"transfered"];

		unsigned long size = [response expectedContentLength];
		if ((long)size == -1)
			size = 0;

		[dictionary setObject:[NSNumber numberWithUnsignedLongLong:size] forKey:@"size"];

		[_outlineView reloadItem:dictionary];

		break;
	}
}

- (BOOL) download:(NSURLDownload *) download shouldDecodeSourceDataOfMIMEType:(NSString *) encodingType {
	return NO;
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

		if ([transfer isDownload])
			[[MVFileTransferController defaultController] fileAtPathDidFinish:((MVDownloadFileTransfer *)transfer).destination];

		if ([[NSUserDefaults standardUserDefaults] integerForKey:@"JVRemoveTransferedItems"] == 2) {
			[[_activity objectForKey:transfer.user.connection] removeObjectIdenticalTo:dictionary];
			[_outlineView reloadData];

			return;
		}

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

	if ([[NSUserDefaults standardUserDefaults] integerForKey:@"JVAutoAcceptFilesFrom"] == 3)
		[self _setDestinationForTransfer:transfer shouldAsk:NO];
	else if ([[NSUserDefaults standardUserDefaults] integerForKey:@"JVAutoAcceptFilesFrom"] == 2) {
//		JVBuddy *buddy = [[MVBuddyListController sharedBuddyList] buddyForNickname:[transfer user] onServer:[(MVChatConnection *)[transfer connection] server]];
//		if (buddy) [self _setDestinationForTransfer:transfer shouldAsk:NO]
//		else [self _setDestinationForTransfer:transfer shouldAsk:YES]
		[self _setDestinationForTransfer:transfer shouldAsk:YES];
	} else if ([[NSUserDefaults standardUserDefaults] integerForKey:@"JVAutoAcceptFilesFrom"] == 1)
		[self _setDestinationForTransfer:transfer shouldAsk:YES];

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
	if (item == CQDirectDownloadKey)
		return NSLocalizedString(@"Downloads", @"Downloads header title");

	return [item description];
}

- (BOOL) outlineView:(NSOutlineView *) outlineView isGroupItem:(id) item {
	return [self _isHeaderItem:item]; // top level, shows the connection name
}

#pragma mark -

- (NSCell *) outlineView:(NSOutlineView *) outlineView dataCellForTableColumn:(NSTableColumn *) tableColumn item:(id) item {
	if ([self _isHeaderItem:item]) {
		if (!_groupCell)
			_groupCell = [[CQGroupCell alloc] initTextCell:@""];
		return _groupCell;
	}

	NSString *type = [item objectForKey:@"type"];
	if (type == CQActivityTypeChatInvite || type == CQActivityTypeDirectChatInvite) {
		if (!_titleCell)
			_titleCell = [[CQSubtitleCell alloc] init];
		return _titleCell;
	}

	if (type == CQActivityTypeFileTransfer || type == CQActivityTypeDirectDownload) {
		if (type == CQActivityTypeFileTransfer) {
			MVFileTransfer *transfer = [item objectForKey:@"transfer"];
			if (transfer.status == MVFileTransferNormalStatus) {
				CQDownloadCell *fileTransferCell = [item objectForKey:@"cell"];
				if (!fileTransferCell) {
					// Make a new cell for each file transfer; otherwise we'll be reusing the same progress indicator view for multiple cells.
					fileTransferCell = [[CQDownloadCell alloc] init];
					[item setObject:fileTransferCell forKey:@"cell"];
				}
				return fileTransferCell;
			}
		} else {
			// check the state
			CQDownloadCell *fileTransferCell = [item objectForKey:@"cell"];
			if (!fileTransferCell) {
				// Make a new cell for each file transfer; otherwise we'll be reusing the same progress indicator view for multiple cells.
				fileTransferCell = [[CQDownloadCell alloc] init];
				[item setObject:fileTransferCell forKey:@"cell"];
			}
			return fileTransferCell;
		}

		if (!_titleCell)
			_titleCell = [[CQSubtitleCell alloc] init];
		return _titleCell;
	}

	return nil;
}

- (CGFloat) outlineView:(NSOutlineView *) outlineView heightOfRowByItem:(id) item {
	return (item && [self _isHeaderItem:item]) ? 19. :40.;
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
		groupCell.unansweredActivityCount = [outlineView isItemExpanded:item] ? 0 :((NSArray *)[_activity objectForKey:item]).count;

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
			// subtitle:@"lastMessageHere";

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
			titleFormat = NSLocalizedString(@"Accepted direct chat with %@", @"cell label text format"); // left:show, right:close
			// subtitle:show last chat line

			titleCell.leftButtonCell.action = @selector(showChatPanel:); // magnifying glass
			titleCell.rightButtonCell.action = @selector(removeRowFromWindow:); // x
			break;
		case MVDirectChatConnectionWaitingStatus:
			titleFormat = NSLocalizedString(@"Direct chat request from %@", @"cell label text format"); // left:accept, right:reject
			// show shared chat rooms

			titleCell.leftButtonCell.action = @selector(acceptChatInvite:); // check
			titleCell.rightButtonCell.action = @selector(rejectChatInvite:); // x
			break;
		case MVDirectChatConnectionDisconnectedStatus:
			hidesLeftButton = YES; // right:close/remove
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

	if (type == CQActivityTypeDirectDownload) {

	}

	if (type == CQActivityTypeFileTransfer) {
		MVFileTransfer *transfer = [item objectForKey:@"transfer"];

		if ([transfer isKindOfClass:[MVDownloadFileTransfer class]])
			title = [((MVDownloadFileTransfer *)transfer).originalFileName retain];
		else title = [[((MVUploadFileTransfer *)transfer).source lastPathComponent] retain];

		CQDownloadCell *fileTransferCell = [item objectForKey:@"cell"];
		if (fileTransferCell == cell) {
			fileTransferCell.progressIndicator.doubleValue = transfer.transfered / transfer.finalSize;

			// subtitle:x KB of y MB (zz KB/s)— a minutes remaining

			return;
		}

		titleCell.leftButtonCell.action = @selector(acceptFileTransfer:);
		titleCell.rightButtonCell.action = @selector(rejectFileTransfer:);

		switch (transfer.status) {
		case MVFileTransferDoneStatus:
			break;
		case MVFileTransferHoldingStatus:
			break;
		case MVFileTransferStoppedStatus:
			break;
		case MVFileTransferErrorStatus:
			break;
		case MVFileTransferNormalStatus:
			// handled by checking if the file transfer cell is returned -- which only happens in this status
		default:
			break;
		}
	}

	titleCell.hidesLeftButton = hidesLeftButton;

	titleCell.titleText = title;
	[title release];

	if ([cell respondsToSelector:@selector(setSubtitleText:)]) {
		[cell setSubtitleText:subtitle];
		[subtitle release];
	}
}

#pragma mark -

- (NSString *) panel:(id) sender userEnteredFilename:(NSString *) filename confirmed:(BOOL) confirmed {
	return (confirmed ? [filename stringByAppendingString:@".colloquyFake"] :filename);
}

#pragma mark -

- (id) _itemForTransfer:(MVFileTransfer *) transfer {
	for (NSDictionary *activity in [_activity objectForKey:transfer.user.connection]) {
		if ([activity objectForKey:@"type"] != CQActivityTypeFileTransfer)
			continue;
		if ([activity objectForKey:@"transfer"] == transfer)
			return activity;
	}
	return nil;
}

- (void) _setDestination:(NSString *) destination forTransfer:(MVDownloadFileTransfer *) transfer checkIfFileExists:(BOOL) checkIfFileExists {
	if (!destination.length)
		destination = transfer.destination;

	BOOL resumeIfPossible = YES;
	if (checkIfFileExists) {
		if ([[NSFileManager defaultManager] fileExistsAtPath:destination]) {
			NSNumber *size = [[[NSFileManager defaultManager] attributesOfItemAtPath:destination error:nil] objectForKey:NSFileSize];
			if (size.unsignedLongLongValue < transfer.finalSize) {
//				if ([[NSUserDefaults standardUserDefaults] integerForKey:@"JVFileExists"] == 1) // auto resume, do nothing
				if ([[NSUserDefaults standardUserDefaults] integerForKey:@"JVFileExists"] == 2) // auto cancel
					return;
				else if ([[NSUserDefaults standardUserDefaults] integerForKey:@"JVFileExists"] == 3) // auto overwrite
					resumeIfPossible = NO; // and fall through
				else {
					NSInteger result = NSRunAlertPanel(NSLocalizedString(@"Save", "save dialog title"), NSLocalizedString(@"The file %@ in %@ already exists. Would you like to resume from where a previous transfer stopped or replace it?", "replace or resume transfer save dialog message"), NSLocalizedString(@"Resume", "resume button name"), NSLocalizedString(@"Replace", "replace button name"), NSLocalizedString(@"Save As…", "save as button name"), NSLocalizedString(@"Cancel", "cancel button"), [[NSFileManager defaultManager] displayNameAtPath:destination], [destination stringByDeletingLastPathComponent]);
					if (result == 4) // cancel
						return;
					if (result == 3) { // save as
						[self _setDestinationForTransfer:transfer shouldAsk:YES];
						return;
					}
					if (result == 2) // replace
						resumeIfPossible = NO;
					// else if (result == 1) // resume, do nothing
				}
			} else {
				NSInteger result = NSRunAlertPanel(NSLocalizedString(@"Save", "save dialog title"), NSLocalizedString(@"The file %@ in %@ already exists and can't be resumed. Replace it?", "replace transfer save dialog message"), NSLocalizedString(@"Replace", "replace button name"), NSLocalizedString(@"Save As…", "save as button name"), NSLocalizedString(@"Cancel", "cancel button"), nil, [[NSFileManager defaultManager] displayNameAtPath:destination], [destination stringByDeletingLastPathComponent]);
				if (result == 2) { // save as
					[self _setDestinationForTransfer:transfer shouldAsk:YES];
					return;
				}
				if (result == 3) // cancel
					return;
				if (result == 1) // replace
					resumeIfPossible = NO;
			}
		}
	} else resumeIfPossible = NO;

	[transfer setDestination:destination renameIfFileExists:NO];
	[transfer acceptByResumingIfPossible:resumeIfPossible];

	[_outlineView reloadItem:[self _itemForTransfer:transfer]];
}

- (void) _fileSavePanelDidEnd:(NSSavePanel *) savePanel returnCode:(int) returnCode contextInfo:(void *) context {
	if (returnCode == NSCancelButton)
		return;

	MVFileTransfer *transfer = (MVFileTransfer *)context;
	[self _setDestination:savePanel.URL.absoluteString forTransfer:(MVDownloadFileTransfer *)transfer checkIfFileExists:NO];
}

- (void) _setDestinationForTransfer:(MVFileTransfer *) transfer shouldAsk:(BOOL) shouldAsk {
	MVDownloadFileTransfer *downloadFileTransfer = (MVDownloadFileTransfer *)transfer;
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"JVAskForTransferSaveLocation"] || shouldAsk) {
		NSSavePanel *savePanel = [NSSavePanel savePanel];
		savePanel.nameFieldLabel = downloadFileTransfer.originalFileName;
		[savePanel beginSheetForDirectory:[MVFileTransferController userPreferredDownloadFolder] file:downloadFileTransfer.originalFileName modalForWindow:nil modalDelegate:self didEndSelector:@selector(_fileSavePanelDidEnd:returnCode:contextInfo:) contextInfo:transfer];

		return;
	}

	[self _setDestination:[[MVFileTransferController userPreferredDownloadFolder] stringByAppendingPathComponent:downloadFileTransfer.originalFileName] forTransfer:downloadFileTransfer checkIfFileExists:YES];
}

#pragma mark -

- (void) cancelFileTransfer:(id) sender {
	id item = [_outlineView itemAtRow:[sender clickedRow]];
	if ([item objectForKey:@"type"] != CQActivityTypeFileTransfer)
		return;
	MVFileTransfer *transfer = [item objectForKey:@"transfer"];
	[transfer cancel];
	[_outlineView reloadItem:item];
}

- (void) acceptFileTransfer:(id) sender {
	id item = [_outlineView itemAtRow:[sender clickedRow]];
	MVDownloadFileTransfer *transfer = [item objectForKey:@"transfer"];

	[self _setDestinationForTransfer:transfer shouldAsk:NO];
}

- (void) rejectFileTransfer:(id) sender {
	id item = [_outlineView itemAtRow:[sender clickedRow]];
	MVDownloadFileTransfer *transfer = [item objectForKey:@"transfer"];
	[transfer reject];
	[_outlineView reloadItem:item];
}

- (void) showFileTransferFileInFinder:(id) sender {
	id item = [_outlineView itemAtRow:[sender clickedRow]];
	MVFileTransfer *transfer = [item objectForKey:@"transfer"];
	NSString *destination = nil;

	if ([transfer isKindOfClass:[MVUploadFileTransfer class]]) {
		NSString *source = ((MVUploadFileTransfer *)transfer).source;
		destination = [source stringByReplacingOccurrencesOfString:[source lastPathComponent] withString:@""];
	} else destination = ((MVDownloadFileTransfer *)transfer).destination;

	[[NSWorkspace sharedWorkspace] selectFile:destination inFileViewerRootedAtPath:@""];
}

#pragma mark -

- (void) acceptChatInvite:(id) sender {
	id item = [_outlineView itemAtRow:[sender clickedRow]];
	if ([item objectForKey:@"type"] == CQDirectChatConnectionKey) {
		MVDirectChatConnection *connection = [item objectForKey:@"connection"];
		[[JVChatController defaultController] chatViewControllerForDirectChatConnection:connection ifExists:NO userInitiated:NO];
		[connection initiate];

		return;
	}

	id room = [item objectForKey:@"room"];
	if ([room isKindOfClass:[MVChatRoom class]]) room = ((MVChatRoom *)room).name;
	[[item objectForKey:@"connection"] joinChatRoomNamed:room];
	[item setObject:CQActivityStatusAccepted forKey:@"status"];

	[_outlineView reloadItem:item];
}

- (void) rejectChatInvite:(id) sender {
	id item = [_outlineView itemAtRow:[sender clickedRow]];
	[item setObject:[NSDate date] forKey:@"date"];
	[item setObject:CQActivityStatusRejected forKey:@"status"];
	[_outlineView reloadItem:item];
}

- (void) requestChatInvite:(id) sender {
	id item = [_outlineView itemAtRow:[sender clickedRow]];
	if ([item objectForKey:@"type"] == CQDirectChatConnectionKey) {
		// start a new dcc chat

		return;
	}

	// /knock
}

#pragma mark -

- (void) showChatPanel:(id) sender {
	id item = [_outlineView itemAtRow:[sender clickedRow]];
}

- (void) removeRowFromWindow:(id) sender {
	id item = [_outlineView itemAtRow:[sender clickedRow]];
	if ([item objectForKey:@"type"] == CQActivityTypeFileTransfer)
		[item removeObjectForKey:@"cell"];
	[[_activity objectForKey:[_outlineView parentForItem:item]] removeObjectIdenticalTo:item];
	[_outlineView reloadData];
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

- (NSUInteger) _downloadCount {
	return [self _countForType:CQActivityTypeDirectDownload inConnection:CQDirectDownloadKey];
}

- (NSUInteger) _fileTransferCountForConnection:(MVChatConnection *) connection {
	return [self _countForType:CQActivityTypeFileTransfer inConnection:connection];
}

- (NSUInteger) _invitationCountForConnection:(MVChatConnection *) connection {
	return [self _countForType:CQActivityTypeChatInvite inConnection:connection];
}

#pragma mark -

- (BOOL) _isHeaderItem:(id) item {
	return ([item isKindOfClass:[MVChatConnection class]] || item == CQDirectChatConnectionKey || item == CQDirectDownloadKey);
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
	if (type == CQActivityTypeFileTransfer || type == CQActivityTypeDirectDownload) // file transfers are sorted by time added, so just add to the end
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
