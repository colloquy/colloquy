#import <Cocoa/Cocoa.h>
#import <ChatCore/MVChatConnection.h>
#import <WebKit/WebDownload.h>

#import "MVFileTransferController.h"
//#import "MVChatWindowController.h"
#import "JVDetailCell.h"

static MVFileTransferController *sharedInstance = nil;

static NSString *MVToolbarStopItemIdentifier = @"MVToolbarStopItem";
static NSString *MVToolbarRevealItemIdentifier = @"MVToolbarRevealItem";
static NSString *MVToolbarClearItemIdentifier = @"MVToolbarClearItem";

NSString *MVPrettyFileSize( unsigned long size ) {
	NSString *ret = nil;
	if( size == 0. ) ret = NSLocalizedString( @"Zero bytes", "no file size" );
	else if( size > 0. && size < 1024. ) ret = [NSString stringWithFormat:NSLocalizedString( @"%lu bytes", "file size measured in bytes" ), size];
	else if( size >= 1024. && size < pow( 1024., 2. ) ) ret = [NSString stringWithFormat:NSLocalizedString( @"%.1f KB", "file size measured in kilobytes" ), ( size / 1024. )];
	else if( size >= pow( 1024., 2. ) && size < pow( 1024., 3. ) ) ret = [NSString stringWithFormat:NSLocalizedString( @"%.2f MB", "file size measured in megabytes" ), ( size / pow( 1024., 2. ) )];
	else if( size >= pow( 1024., 3. ) && size < pow( 1024., 4. ) ) ret = [NSString stringWithFormat:NSLocalizedString( @"%.3f GB", "file size measured in gigabytes" ), ( size / pow( 1024., 3. ) )];
	else if( size >= pow( 1024., 4. ) ) ret = [NSString stringWithFormat:NSLocalizedString( @"%.4f TB", "file size measured in terabytes" ), ( size / pow( 1024., 4. ) )];
	return [[ret retain] autorelease];
}

NSString *MVReadableTime( NSTimeInterval date, BOOL longFormat ) {
	NSTimeInterval secs = [[NSDate date] timeIntervalSince1970] - date;
	unsigned int i = 0, stop = 0;
	NSDictionary *desc = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString( @"second", "singular second" ), [NSNumber numberWithUnsignedInt:1], NSLocalizedString( @"minute", "singular minute" ), [NSNumber numberWithUnsignedInt:60], NSLocalizedString( @"hour", "singular hour" ), [NSNumber numberWithUnsignedInt:3600], NSLocalizedString( @"day", "singular day" ), [NSNumber numberWithUnsignedInt:86400], NSLocalizedString( @"week", "singular week" ), [NSNumber numberWithUnsignedInt:604800], NSLocalizedString( @"month", "singular month" ), [NSNumber numberWithUnsignedInt:2628000], NSLocalizedString( @"year", "singular year" ), [NSNumber numberWithUnsignedInt:31536000], nil];
	NSDictionary *plural = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString( @"seconds", "plural seconds" ), [NSNumber numberWithUnsignedInt:1], NSLocalizedString( @"minutes", "plural minutes" ), [NSNumber numberWithUnsignedInt:60], NSLocalizedString( @"hours", "plural hours" ), [NSNumber numberWithUnsignedInt:3600], NSLocalizedString( @"days", "plural days" ), [NSNumber numberWithUnsignedInt:86400], NSLocalizedString( @"weeks", "plural weeks" ), [NSNumber numberWithUnsignedInt:604800], NSLocalizedString( @"months", "plural months" ), [NSNumber numberWithUnsignedInt:2628000], NSLocalizedString( @"years", "plural years" ), [NSNumber numberWithUnsignedInt:31536000], nil];
	NSDictionary *use = nil;
	NSMutableArray *breaks = nil;
	unsigned int val = 0.;
	NSString *retval = nil;

	if( secs < 0 ) secs *= -1;

	breaks = [[[desc allKeys] mutableCopy] autorelease];
	[breaks sortUsingSelector:@selector( compare: )];

	while( i < [breaks count] && secs >= (NSTimeInterval) [[breaks objectAtIndex:i] unsignedIntValue] ) i++;
	if( i > 0 ) i--;
	stop = [[breaks objectAtIndex:i] unsignedIntValue];

	val = (unsigned int) ( secs / stop );
	use = ( val > 1 ? plural : desc );
	retval = [NSString stringWithFormat:@"%d %@", val, [use objectForKey:[NSNumber numberWithUnsignedInt:stop]]];
	if( longFormat && i > 0 ) {
		unsigned int rest = (unsigned int) ( (unsigned int) secs % stop );
		stop = [[breaks objectAtIndex:--i] unsignedIntValue];
		rest = (unsigned int) ( rest / stop );
		if( rest > 0 ) {
			use = ( rest > 1 ? plural : desc );
			retval = [retval stringByAppendingFormat:@" %d %@", rest, [use objectForKey:[breaks objectAtIndex:i]]];
		}
	}
	return [[retval retain] autorelease];
}

#pragma mark -

@interface MVFileTransferController (MVFileTransferControllerPrivate)
- (void) _updateProgress:(id) sender;
@end

#pragma mark -

@implementation MVFileTransferController
+ (MVFileTransferController *) defaultManager {
	extern MVFileTransferController *sharedInstance;
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] initWithWindowNibName:nil] ) );
}

#pragma mark -

- (id) initWithWindowNibName:(NSString *) windowNibName {
	if( ( self = [super initWithWindowNibName:@"MVFileTransfer"] ) ) {
		_transferStorage = [[NSMutableArray array] retain];
		_calculationItems = [[NSMutableArray array] retain];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _incomingFile: ) name:MVChatConnectionFileTransferAvailableNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _outgoingFile: ) name:MVChatConnectionFileTransferOfferedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _transferStarted: ) name:MVChatConnectionFileTransferStartedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _transferFinished: ) name:MVChatConnectionFileTransferFinishedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _transferError: ) name:MVChatConnectionFileTransferErrorNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _transferStatus: ) name:MVChatConnectionFileTransferStatusNotification object:nil];

		_updateTimer = [[NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector( _updateProgress: ) userInfo:nil repeats:YES] retain];
	}
	return self;
}

- (void) release {
	if( ( [self retainCount] - 1 ) == 1 )
		[_updateTimer invalidate];
	[super release];
}

- (void) dealloc {
	extern MVFileTransferController *sharedInstance;

	[_transferStorage autorelease];
	[_calculationItems autorelease];
	[_updateTimer autorelease];

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	_transferStorage = nil;
	_calculationItems = nil;
	_updateTimer = nil;

	if( self == sharedInstance ) sharedInstance = nil;
	[super dealloc];
}

- (void) windowDidLoad {
	NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"Transfers"] autorelease];
	NSTableColumn *theColumn = nil;
	id prototypeCell = nil;

	[(NSPanel *)[self window] setFloatingPanel:NO];

	[currentFiles setVerticalMotionCanBeginDrag:NO];
	[currentFiles setDoubleAction:@selector( _openFile: )];
	[currentFiles setAutosaveName:@"Transfers"];
	[currentFiles setAutosaveTableColumns:YES];

	theColumn = [currentFiles tableColumnWithIdentifier:@"file"];
	prototypeCell = [[JVDetailCell new] autorelease];
	[prototypeCell setFont:[NSFont systemFontOfSize:11.]];
	[theColumn setDataCell:prototypeCell];

	theColumn = [currentFiles tableColumnWithIdentifier:@"status"];
	[[theColumn headerCell] setImage:[NSImage imageNamed:@"statusHeader"]];

	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	[[self window] setToolbar:toolbar];

	[progressBar setMinValue:0.];
	[progressBar setUsesThreadedAnimation:YES];
	[self _updateProgress:nil];

	[self setWindowFrameAutosaveName:@"Transfers"];
}

#pragma mark -

- (IBAction) showTransferManager:(id) sender {
	[[self window] orderFront:nil];
}

#pragma mark -

- (void) downloadFileAtURL:(NSURL *) url toLocalFile:(NSString *) path {
	WebDownload *download = [[[WebDownload alloc] initWithRequest:[NSURLRequest requestWithURL:url] delegate:self] autorelease];
	if( ! download ) {
		NSBeginAlertSheet( @"Invalid URL", nil, nil, nil, [self window], nil, nil, nil, nil, @"The download URL is either invalid or unsupported." );
		return;
	}

	if( path ) [download setDestination:path allowOverwrite:NO];

	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	[info setObject:[NSNumber numberWithUnsignedLong:0] forKey:@"transfered"];
	[info setObject:[NSNumber numberWithUnsignedInt:0] forKey:@"rate"];
	[info setObject:[NSNumber numberWithUnsignedLong:0] forKey:@"size"];
	[info setObject:[NSNumber numberWithUnsignedInt:MVDownloadTransfer] forKey:@"type"];
	[info setObject:[NSNumber numberWithUnsignedInt:MVTransferHolding] forKey:@"status"];
	[info setObject:[download description] forKey:@"identifier"];
	[info setObject:download forKey:@"controller"];
	[info setObject:url forKey:@"url"];
	if( path ) [info setObject:path forKey:@"path"];
	else [info setObject:[[url path] lastPathComponent] forKey:@"path"];

	[_transferStorage addObject:info];

	[self showTransferManager:nil];

	[self _updateProgress:nil];	
}

- (void) addFileTransfer:(NSString *) identifier withUser:(NSString *) user forConnection:(MVChatConnection *) connection asType:(MVTransferOperation) type withSize:(unsigned long) size withLocalFile:(NSString *) path {
	NSEnumerator *enumerator = nil;
	NSMutableDictionary *info = nil;
	NSParameterAssert( identifier != nil );
	NSParameterAssert( user != nil );
	NSParameterAssert( type != 0 );

	[self showTransferManager:nil];

	enumerator = [_transferStorage objectEnumerator];
	while( ( info = [enumerator nextObject] ) ) {
		if( [[info objectForKey:@"user"] isEqualToString:user] && [[info objectForKey:@"path"] isEqualToString:path] && [[info objectForKey:@"size"] unsignedLongValue] == size && [[info objectForKey:@"type"] unsignedIntValue] == type ) {
			[info setObject:[NSNumber numberWithUnsignedInt:MVTransferHolding] forKey:@"status"];
			[info setObject:identifier forKey:@"identifier"];
			[self _updateProgress:nil];
			return;
		}
	}

	info = [NSMutableDictionary dictionary];
	[info setObject:[NSNumber numberWithUnsignedLong:0] forKey:@"transfered"];
	[info setObject:[NSNumber numberWithUnsignedInt:0] forKey:@"rate"];
	[info setObject:[NSNumber numberWithUnsignedLong:size] forKey:@"size"];
	[info setObject:[NSNumber numberWithUnsignedInt:type] forKey:@"type"];
	[info setObject:[NSNumber numberWithUnsignedInt:MVTransferHolding] forKey:@"status"];
	[info setObject:identifier forKey:@"identifier"];
	[info setObject:connection forKey:@"connection"];
	[info setObject:user forKey:@"user"];
	[info setObject:path forKey:@"path"];

	[_transferStorage addObject:info];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _changeUser: ) name:MVChatConnectionUserNicknameChangedNotification object:connection];

	[self _updateProgress:nil];
}

- (BOOL) updateFileTransfer:(NSString *) identifier withNewTransferedSize:(unsigned long) transfered {
	NSEnumerator *enumerator = nil;
	NSMutableDictionary *info = nil;
	NSParameterAssert( identifier != nil );
	BOOL ret = NO;

	enumerator = [_transferStorage objectEnumerator];
	while( ( info = [enumerator nextObject] ) ) {
		if( [[info objectForKey:@"status"] unsignedIntValue] != MVTransferDone && [identifier isEqualToString:[info objectForKey:@"identifier"]] ) {
			NSTimeInterval timeslice = [[info objectForKey:@"started"] timeIntervalSinceNow] * -1;
			[info setObject:[NSNumber numberWithUnsignedLong:transfered] forKey:@"transfered"];
			if( transfered != [[info objectForKey:@"size"] unsignedLongValue] )
				[info setObject:[NSNumber numberWithDouble:(transfered / timeslice)] forKey:@"rate"];
			if( ! [info objectForKey:@"started"] )
				[info setObject:[NSDate date] forKey:@"started"];
			ret = YES;
			break;
		}
	}
	return ret;
}

- (BOOL) updateFileTransfer:(NSString *) identifier withStatus:(MVTransferStatus) status {
	NSEnumerator *enumerator = nil;
	NSMutableDictionary *info = nil;
	NSParameterAssert( identifier != nil );
	BOOL ret = NO;

	enumerator = [_transferStorage objectEnumerator];
	while( ( info = [enumerator nextObject] ) ) {
		if( [identifier isEqualToString:[info objectForKey:@"identifier"]] ) {
			if( ! [info objectForKey:@"started"] ) [info setObject:[NSDate date] forKey:@"started"];
			[info setObject:[NSNumber numberWithUnsignedInt:status] forKey:@"status"];
			ret = YES;
			break;
		}
	}
	return ret;
}

#pragma mark -

- (IBAction) stopSelectedTransfer:(id) sender {
	NSMutableDictionary *info = nil;
	if( [currentFiles selectedRow] != -1 ) {
		info = [_transferStorage objectAtIndex:[currentFiles selectedRow]];
		if( [info objectForKey:@"connection"] )
			[[info objectForKey:@"connection"] cancelFileTransfer:[info objectForKey:@"identifier"]];
		else if( [info objectForKey:@"controller"] )
			[[info objectForKey:@"controller"] cancel];
		[info setObject:[NSNumber numberWithUnsignedInt:MVTransferStopped] forKey:@"status"];
		[self _updateProgress:nil];
	}
}

- (IBAction) clearFinishedTransfers:(id) sender {
	unsigned i = 0;
	NSDictionary *info = nil;
	if( [currentFiles selectedRow] == -1 ) {
		for( i = 0; i < [_transferStorage count]; ) {
			info = [_transferStorage objectAtIndex:i];
			if( [[info objectForKey:@"status"] unsignedIntValue] == MVTransferDone || [[info objectForKey:@"status"] unsignedIntValue] == MVTransferError || [[info objectForKey:@"status"] unsignedIntValue] == MVTransferStopped ) {
				if( [info objectForKey:@"connection"] )
					[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:[info objectForKey:@"connection"]];
				[_calculationItems removeObject:info];
				[_transferStorage removeObject:info];
			} else i++;
		}
		[self _updateProgress:nil];
	} else if( [currentFiles numberOfSelectedRows] == 1 ) {
		info = [_transferStorage objectAtIndex:[currentFiles selectedRow]];
		if( [[info objectForKey:@"status"] unsignedIntValue] == MVTransferDone || [[info objectForKey:@"status"] unsignedIntValue] == MVTransferError || [[info objectForKey:@"status"] unsignedIntValue] == MVTransferStopped ) {
			if( [info objectForKey:@"connection"] )
				[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:[info objectForKey:@"connection"]];
			[_calculationItems removeObject:info];
			[_transferStorage removeObject:info];
		}
		[self _updateProgress:nil];
	}
}

- (IBAction) revealSelectedFile:(id) sender {
	NSDictionary *info = nil;
	if( [currentFiles numberOfSelectedRows] == 1 ) {
		info = [_transferStorage objectAtIndex:[currentFiles selectedRow]];
		[[NSWorkspace sharedWorkspace] selectFile:[info objectForKey:@"path"] inFileViewerRootedAtPath:@""];
	}
}

#pragma mark -

- (IBAction) copy:(id) sender {
	NSEnumerator *enumerator = [currentFiles selectedRowEnumerator];
	NSMutableArray *array = [NSMutableArray array];
	NSMutableString *string = [NSMutableString string];
	id row = nil;
	unsigned i = 0;
	[[NSPasteboard generalPasteboard] declareTypes:[NSArray arrayWithObjects:NSFilenamesPboardType,NSStringPboardType,nil] owner:self];
	while( ( row = [enumerator nextObject] ) ) {
		i = [row unsignedIntValue];
		[array addObject:[[_transferStorage objectAtIndex:i] objectForKey:@"path"]];
		[string appendString:[[[_transferStorage objectAtIndex:i] objectForKey:@"path"] lastPathComponent]];
		if( ! [[[enumerator allObjects] lastObject] isEqual:row] ) [string appendString:@"\n"];
	}
	[[NSPasteboard generalPasteboard] setPropertyList:array forType:NSFilenamesPboardType];
	[[NSPasteboard generalPasteboard] setString:string forType:NSStringPboardType];
}
@end

#pragma mark -

@implementation MVFileTransferController (MVFileTransferControllerDelegate)
- (int) numberOfRowsInTableView:(NSTableView *) view {
	return [_transferStorage count];
}

- (id) tableView:(NSTableView *) view objectValueForTableColumn:(NSTableColumn *) column row:(int) row {
	if( [[column identifier] isEqual:@"file"] ) {
		NSImage *fileIcon = [[NSWorkspace sharedWorkspace] iconForFileType:[[[_transferStorage objectAtIndex:row] objectForKey:@"path"] pathExtension]];
		[fileIcon setScalesWhenResized:YES];
		[fileIcon setSize:NSMakeSize( 16., 16. )];
		return fileIcon;
	} else if( [[column identifier] isEqual:@"size"] ) {
		unsigned long size = [[[_transferStorage objectAtIndex:row] objectForKey:@"size"] unsignedLongValue];
		return ( size ? MVPrettyFileSize( size ) : @"--" );
	} else if( [[column identifier] isEqual:@"user"] ) {
		NSString *ret = [[_transferStorage objectAtIndex:row] objectForKey:@"user"];
		return ( ret ? ret : NSLocalizedString( @"n/a", "not applicable identifier" ) );
	}
	return nil;
}

- (void) tableView:(NSTableView *) view willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) column row:(int) row {
	if( [[column identifier] isEqual:@"file"] ) {
		[cell setMainText:[[[_transferStorage objectAtIndex:row] objectForKey:@"path"] lastPathComponent]];
	} else if( [[column identifier] isEqual:@"status"] ) {
		MVTransferOperation type = (MVTransferOperation) [[[_transferStorage objectAtIndex:row] objectForKey:@"type"] unsignedIntValue];
		MVTransferStatus status = (MVTransferStatus) [[[_transferStorage objectAtIndex:row] objectForKey:@"status"] unsignedIntValue];
		NSString *imageName = @"pending";
		if( status == MVTransferError ) imageName = @"error";
		else if( status == MVTransferStopped ) imageName = @"stopped";
		else if( status == MVTransferDone ) imageName = @"done";
		else if( type == MVUploadTransfer && status == MVTransferNormal ) imageName = @"upload";
		else if( type == MVDownloadTransfer && status == MVTransferNormal ) imageName = @"download";
		[cell setImage:[NSImage imageNamed:imageName]];
	}
}

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	NSEnumerator *enumerator = nil;
	id item = nil;
	BOOL noneSelected = YES;

	enumerator = [[[[self window] toolbar] visibleItems] objectEnumerator];
	if( [currentFiles selectedRow] != -1 ) noneSelected = NO;
	while( ( item = [enumerator nextObject] ) ) {
		if( [[item itemIdentifier] isEqual:MVToolbarStopItemIdentifier] ) {
			if( ! noneSelected && [currentFiles numberOfSelectedRows] == 1 && [[[_transferStorage objectAtIndex:[currentFiles selectedRow]] objectForKey:@"status"] unsignedIntValue] != MVTransferDone )
				[item setAction:@selector( stopSelectedTransfer: )];
			else [item setAction:NULL];
		} else if( [[item itemIdentifier] isEqual:MVToolbarRevealItemIdentifier] ) {
			if( ! noneSelected && [currentFiles numberOfSelectedRows] == 1 ) [item setAction:@selector( revealSelectedFile: )];
			else [item setAction:NULL];
		} else if( [[item itemIdentifier] isEqual:MVToolbarClearItemIdentifier] ) {
			if( ! noneSelected && [currentFiles numberOfSelectedRows] == 1 && [[[_transferStorage objectAtIndex:[currentFiles selectedRow]] objectForKey:@"status"] unsignedIntValue] != MVTransferNormal && [[[_transferStorage objectAtIndex:[currentFiles selectedRow]] objectForKey:@"status"] unsignedIntValue] != MVTransferHolding )
				[item setAction:@selector( clearFinishedTransfers: )];
			else if( noneSelected ) [item setAction:@selector( clearFinishedTransfers: )];
			else [item setAction:NULL];
		}
	}

	enumerator = [currentFiles selectedRowEnumerator];
	[_calculationItems removeAllObjects];
	while( ( item = [enumerator nextObject] ) ) {
		[_calculationItems addObject:[_transferStorage objectAtIndex:[item unsignedIntValue]]];
	}

	[self _updateProgress:nil];
}

- (BOOL) tableView:(NSTableView *) view writeRows:(NSArray *) rows toPasteboard:(NSPasteboard *) board {
	NSEnumerator *enumerator = [rows objectEnumerator];
	NSMutableArray *array = [NSMutableArray array];
	id row;
	[board declareTypes:[NSArray arrayWithObjects:NSFilenamesPboardType,nil] owner:self];

	while( ( row = [enumerator nextObject] ) ) {
		[array addObject:[[_transferStorage objectAtIndex:[row unsignedIntValue]] objectForKey:@"path"]];
	}

	[board setPropertyList:array forType:NSFilenamesPboardType];
	return YES;
}

#pragma mark -

- (NSToolbarItem *) toolbar:(NSToolbar *) toolbar itemForItemIdentifier:(NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdent] autorelease];

	if( [itemIdent isEqual:MVToolbarStopItemIdentifier] ) {
		[toolbarItem setLabel:NSLocalizedString( @"Stop", "short toolbar stop button name" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Stop Tranfser", "name for stop button in customize palette" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Stop File Tranfser", "stop button tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"stop"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:NULL];
	} else if( [itemIdent isEqual:MVToolbarRevealItemIdentifier] ) {
		[toolbarItem setLabel:NSLocalizedString( @"Reveal", "show file in Finder toolbar button name" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Reveal File", "show file in Finder toolbar customize palette name" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Reveal File in Finder", "reveal button tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"reveal"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:NULL];
	} else if( [itemIdent isEqual:MVToolbarClearItemIdentifier] ) {
		[toolbarItem setLabel:NSLocalizedString( @"Clear", "clear finished transfers toolbar button name" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Clear Finished", "clear finished transfers toolbar customize palette name" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Clear Finished Transfers", "clear finished transfers tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"clear"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector( clearFinishedTransfers: )];
	} else toolbarItem = nil;
	return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *) toolbar {
	return [NSArray arrayWithObjects:MVToolbarStopItemIdentifier, MVToolbarClearItemIdentifier,
		NSToolbarSeparatorItemIdentifier, MVToolbarRevealItemIdentifier, nil];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar {
	return [NSArray arrayWithObjects:MVToolbarStopItemIdentifier, MVToolbarClearItemIdentifier,
		MVToolbarRevealItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier, nil];
}

#pragma mark -

- (NSString *) panel:(id) sender userEnteredFilename:(NSString *) filename confirmed:(BOOL) confirmed {
	return ( confirmed ? [filename stringByAppendingString:@".colloquyFake"] : filename );
}

#pragma mark -

- (void) download:(NSURLDownload *) download decideDestinationWithSuggestedFilename:(NSString *) filename {
	NSSavePanel *savePanel = [[NSSavePanel savePanel] retain];
	[savePanel beginSheetForDirectory:NSHomeDirectory() file:filename modalForWindow:nil modalDelegate:self didEndSelector:@selector( _downloadFileSavePanelDidEnd:returnCode:contextInfo: ) contextInfo:(void *) [download retain]];
}

- (void) download:(NSURLDownload *) download didReceiveResponse:(NSURLResponse *) response {
	NSEnumerator *enumerator = nil;
	NSMutableDictionary *info = nil;

	enumerator = [_transferStorage objectEnumerator];
	while( ( info = [enumerator nextObject] ) ) {
		if( [info objectForKey:@"controller"] == download ) {
			[info setObject:[NSNumber numberWithUnsignedInt:[response expectedContentLength]] forKey:@"size"];
			break;
		}
	}

	[self _updateProgress:nil];
}

- (NSWindow *) downloadWindowForAuthenticationSheet:(WebDownload *) download {
	return [self window];
}

- (void) download:(NSURLDownload *) download didReceiveDataOfLength:(unsigned) length {
	NSEnumerator *enumerator = nil;
	NSMutableDictionary *info = nil;

	enumerator = [_transferStorage objectEnumerator];
	while( ( info = [enumerator nextObject] ) ) {
		if( [info objectForKey:@"controller"] == download ) {
			NSTimeInterval timeslice = [[info objectForKey:@"started"] timeIntervalSinceNow] * -1;
			unsigned long transfered = [[info objectForKey:@"transfered"] unsignedIntValue] + length;
			[info setObject:[NSNumber numberWithUnsignedInt:MVTransferNormal] forKey:@"status"];
			[info setObject:[NSNumber numberWithUnsignedLong:transfered] forKey:@"transfered"];
			if( transfered != [[info objectForKey:@"size"] unsignedLongValue] )
				[info setObject:[NSNumber numberWithDouble:(transfered / timeslice)] forKey:@"rate"];
			if( ! [info objectForKey:@"started"] )
				[info setObject:[NSDate date] forKey:@"started"];
			break;
		}
	}
}

- (BOOL) download:(NSURLDownload *) download shouldDecodeSourceDataOfMIMEType:(NSString *) encodingType {
	return NO;
}

- (void) downloadDidFinish:(NSURLDownload *) download {
	NSEnumerator *enumerator = nil;
	NSMutableDictionary *info = nil;
	
	enumerator = [_transferStorage objectEnumerator];
	while( ( info = [enumerator nextObject] ) ) {
		if( [info objectForKey:@"controller"] == download ) {
			[info setObject:[NSNumber numberWithUnsignedInt:MVTransferDone] forKey:@"status"];
			break;
		}
	}
	
	[self _updateProgress:nil];
}

- (void) download:(NSURLDownload *) download didFailWithError:(NSError *) error {
	NSEnumerator *enumerator = nil;
	NSMutableDictionary *info = nil;
	
	enumerator = [_transferStorage objectEnumerator];
	while( ( info = [enumerator nextObject] ) ) {
		if( [info objectForKey:@"controller"] == download ) {
			[info setObject:[NSNumber numberWithUnsignedInt:MVTransferError] forKey:@"status"];
			break;
		}
	}
	
	[self _updateProgress:nil];
}
@end

#pragma mark -

@implementation MVFileTransferController (MVFileTransferControllerPrivate)
- (void) _incomingFile:(NSNotification *) notification {
	NSMutableDictionary *info = [[[notification userInfo] mutableCopy] autorelease];

	[info setObject:[notification object] forKey:@"connection"];

	NSBeginInformationalAlertSheet( NSLocalizedString( @"Incoming File Transfer", "new file transfer dialog title" ), NSLocalizedString( @"Accept", "accept button name" ), NSLocalizedString( @"Refuse", "refuse button name" ), nil, nil, self, @selector( _incomingFileSheetDidEnd:returnCode:contextInfo: ), NULL, (void *) [info retain], NSLocalizedString( @"A file named \"%@\" is being sent to you from %@. This file is %@ in size.", "new file transfer dialog message" ), [info objectForKey:@"filename"], [info objectForKey:@"from"], MVPrettyFileSize( [[info objectForKey:@"size"] unsignedLongValue] ) );
}

- (void) _incomingFileSheetDidEnd:(NSWindow *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	NSDictionary *info = [(NSDictionary *) contextInfo autorelease]; // for the previous retain in _incomingFile:
	if( returnCode == NSOKButton ) {
		NSSavePanel *savePanel = [[NSSavePanel savePanel] retain];
		[sheet close];
		[savePanel setDelegate:self];
		[savePanel beginSheetForDirectory:NSHomeDirectory() file:[info objectForKey:@"filename"] modalForWindow:nil modalDelegate:self didEndSelector:@selector( _incomingFileSavePanelDidEnd:returnCode:contextInfo: ) contextInfo:(void *) [info retain]];
	}
}

- (void) _incomingFileSavePanelDidEnd:(NSSavePanel *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	NSDictionary *info = [(NSDictionary *) contextInfo autorelease]; // for the previous retain in _incomingFileSheetDidEnd:returnCode:contextInfo:
	[sheet autorelease];
	if( returnCode == NSOKButton ) {
		NSString *filename = ( [[sheet filename] hasSuffix:@".colloquyFake"] ? [[sheet filename] stringByDeletingPathExtension] : [sheet filename] );
		NSNumber *size = [[[NSFileManager defaultManager] fileAttributesAtPath:filename traverseLink:YES] objectForKey:@"NSFileSize"];
		BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:filename];
		BOOL resumePossible = ( fileExists && [size unsignedLongValue] < [[info objectForKey:@"size"] unsignedLongValue] ? YES : NO );
		int result = NSOKButton;

		if( resumePossible ) result = NSRunAlertPanel( NSLocalizedString( @"Save", "save dialog title" ), NSLocalizedString( @"The file %@ in %@ already exists. Would you like to resume from where a previous transfer stopped or replace it?", "replace or resume transfer save dialog message" ), NSLocalizedString( @"Resume", "resume button name" ), @"Cancel", NSLocalizedString( @"Replace", "replace button name" ), [filename lastPathComponent], [filename stringByDeletingLastPathComponent] );
		else if( fileExists ) result = NSRunAlertPanel( NSLocalizedString( @"Save", "save dialog title" ), NSLocalizedString( @"The file %@ in %@ already exists and can't be resumed. Replace it?", "replace transfer save dialog message" ), NSLocalizedString( @"Replace", "replace button name" ), @"Cancel", nil, [filename lastPathComponent], [filename stringByDeletingLastPathComponent] );

		if( result == NSCancelButton ) {
			NSSavePanel *savePanel = [[NSSavePanel savePanel] retain];
			[sheet close];
			[savePanel setDelegate:self];
			[savePanel beginSheetForDirectory:[sheet directory] file:[filename lastPathComponent] modalForWindow:nil modalDelegate:self didEndSelector:@selector( _incomingFileSavePanelDidEnd:returnCode:contextInfo: ) contextInfo:(void *) [info retain]];
		} else {
			BOOL resume = ( resumePossible && result == NSOKButton );
			[[info objectForKey:@"connection"] acceptFileTransfer:[info objectForKey:@"identifier"] saveToPath:filename resume:resume];
			[self addFileTransfer:[info objectForKey:@"identifier"] withUser:[info objectForKey:@"from"] forConnection:[info objectForKey:@"connection"] asType:MVDownloadTransfer withSize:[[info objectForKey:@"size"] unsignedLongValue] withLocalFile:filename];
		}
	}
}

- (void) _downloadFileSavePanelDidEnd:(NSSavePanel *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	WebDownload *download = [(WebDownload *) contextInfo autorelease]; // for the previous retain
	[sheet autorelease];
	if( returnCode == NSOKButton ) {
		NSEnumerator *enumerator = nil;
		NSMutableDictionary *info = nil;

		enumerator = [_transferStorage objectEnumerator];
		while( ( info = [enumerator nextObject] ) ) {
			if( [info objectForKey:@"controller"] == download ) {
				[info setObject:[sheet filename] forKey:@"path"];
				break;
			}
		}

		[download setDestination:[sheet filename] allowOverwrite:YES];
		[self _updateProgress:nil];
	} else {
		NSEnumerator *enumerator = nil;
		NSMutableDictionary *info = nil;

		[download cancel];

		enumerator = [_transferStorage objectEnumerator];
		while( ( info = [enumerator nextObject] ) ) {
			if( [info objectForKey:@"controller"] == download ) {
				[info setObject:[NSNumber numberWithUnsignedInt:MVTransferStopped] forKey:@"status"];
				break;
			}
		}

		[self _updateProgress:nil];
	}
}

- (void) _outgoingFile:(NSNotification *) notification {
	NSDictionary *info = [notification userInfo];
	[self addFileTransfer:[info objectForKey:@"identifier"] withUser:[info objectForKey:@"to"] forConnection:[notification object] asType:MVUploadTransfer withSize:[[info objectForKey:@"size"] unsignedLongValue] withLocalFile:[info objectForKey:@"path"]];
}

- (void) _transferStarted:(NSNotification *) notification {
	NSDictionary *info = [notification userInfo];
	[self updateFileTransfer:[info objectForKey:@"identifier"] withStatus:MVTransferNormal];
}

- (void) _transferFinished:(NSNotification *) notification {
	NSDictionary *info = [notification userInfo];
	[self updateFileTransfer:[info objectForKey:@"identifier"] withNewTransferedSize:[[info objectForKey:@"size"] unsignedLongValue]];
	[self updateFileTransfer:[info objectForKey:@"identifier"] withStatus:MVTransferDone];
}

- (void) _transferError:(NSNotification *) notification {
	NSDictionary *info = [notification userInfo];
	[self updateFileTransfer:[info objectForKey:@"identifier"] withStatus:MVTransferError];
}

- (void) _transferStatus:(NSNotification *) notification {
	NSDictionary *info = [notification userInfo];
	[self updateFileTransfer:[info objectForKey:@"identifier"] withNewTransferedSize:[[info objectForKey:@"transfered"] unsignedLongValue]];
}

- (void) _openFile:(id) sender {
	NSDictionary *info = nil;
	NSEnumerator *enumerator = [currentFiles selectedRowEnumerator];
	id item = nil;

	while( ( item = [enumerator nextObject] ) ) {
		info = [_transferStorage objectAtIndex:[currentFiles selectedRow]];
		[[NSWorkspace sharedWorkspace] openFile:[info objectForKey:@"path"]];
	}
}

- (void) _updateProgress:(id) sender {
	NSString *str = nil;
	NSEnumerator *enumerator = nil;
	NSDictionary *info = nil;
	unsigned long totalSizeUp = 0, totalTransferedUp = 0, totalTransfered = 0, totalSize = 0;
	unsigned long totalSizeDown = 0, totalTransferedDown = 0;
	double upRate = 0., downRate = 0., avgRate = 0.;
	unsigned upCount = 0, downCount = 0;
	NSDate *startDate = nil;

	if( ! [[self window] isVisible] ) return;

	[currentFiles reloadData];
	if( [_calculationItems count] ) enumerator = [_calculationItems objectEnumerator];
	else enumerator = [_transferStorage objectEnumerator];
	while( ( info = [enumerator nextObject] ) ) {
		if( [[info objectForKey:@"status"] unsignedIntValue] == MVTransferNormal )
			startDate = [[[info objectForKey:@"started"] retain] autorelease];
		else startDate = nil;
		if( [[info objectForKey:@"type"] unsignedIntValue] == MVUploadTransfer ) {
			totalSizeUp += [[info objectForKey:@"size"] unsignedLongValue];
			totalTransferedUp += [[info objectForKey:@"transfered"] unsignedLongValue];
			upRate += [[info objectForKey:@"rate"] doubleValue];
			upCount++;
		} else if( [[info objectForKey:@"type"] unsignedIntValue] == MVDownloadTransfer ) {
			totalSizeDown += [[info objectForKey:@"size"] unsignedLongValue];
			totalTransferedDown += [[info objectForKey:@"transfered"] unsignedLongValue];
			downRate += [[info objectForKey:@"rate"] doubleValue];
			downCount++;
		}
	}

	totalTransfered = totalTransferedDown + totalTransferedUp;
	totalSize = totalSizeDown + totalSizeUp;
	if( upCount && downCount ) {
		upRate = upRate / (float) upCount;
		if( ! totalTransferedUp || ! totalSizeUp ) {
			str = NSLocalizedString( @"nothing uploaded yet", "status of pending upload file transfer" );
		} else if( totalSizeUp != totalTransferedUp ) {
			str = [NSString stringWithFormat:NSLocalizedString( @"%@ of %@ uploaded, at %@ per second", "status of current upload file transfer" ), MVPrettyFileSize( totalTransferedUp ), MVPrettyFileSize( totalSizeUp ), MVPrettyFileSize( upRate )];
		} else if( totalTransferedUp >= totalSizeUp ) {
			str = [NSString stringWithFormat:NSLocalizedString( @"total of %@ uploaded, at %@ per second", "results final upload file transfer" ), MVPrettyFileSize( totalSizeUp ), MVPrettyFileSize( upRate )];
		}
		str = [str stringByAppendingString:@"\n"];
		downRate = downRate / (float) downCount;
		if( ! totalTransferedDown || ! totalSizeDown ) {
			str = [str stringByAppendingString:NSLocalizedString( @"nothing downloaded yet", "status of pending download file transfer" )];
		} else if( totalSizeDown != totalTransferedDown ) {
			str = [str stringByAppendingFormat:NSLocalizedString( @"%@ of %@ downloaded, at %@ per second", "status of current download file transfer" ), MVPrettyFileSize( totalTransferedDown ), MVPrettyFileSize( totalSizeDown ), MVPrettyFileSize( downRate )];
		} else if( totalTransferedDown >= totalSizeDown ) {
			str = [str stringByAppendingFormat:NSLocalizedString( @"total of %@ downloaded, at %@ per second", "results final download file transfer" ), MVPrettyFileSize( totalSizeDown ), MVPrettyFileSize( downRate )];
		}
	} else if( upCount || downCount ) {
		avgRate = ( upRate + downRate ) / ( (float) upCount + (float) downCount );
		if( ! totalTransfered || ! totalSize ) {
			totalSize = 1;
			if( downCount ) str = NSLocalizedString( @"nothing downloaded yet", "status of pending download file transfer" );
			else if( upCount ) str = NSLocalizedString( @"nothing uploaded yet", "status of pending upload file transfer" );
		} else if( totalSize != totalTransfered ) {
			if( downCount ) str = [NSString stringWithFormat:NSLocalizedString( @"%@ of %@ downloaded, at %@ per second", "status of current download file transfer" ), MVPrettyFileSize( totalTransfered ), MVPrettyFileSize( totalSize ), MVPrettyFileSize( avgRate )];
			else if( upCount ) str = [NSString stringWithFormat:NSLocalizedString( @"%@ of %@ uploaded, at %@ per second", "status of current upload file transfer" ), MVPrettyFileSize( totalTransfered ), MVPrettyFileSize( totalSize ), MVPrettyFileSize( avgRate )];
		} else if( totalTransfered >= totalSize ) {
			if( downCount ) str = [NSString stringWithFormat:NSLocalizedString( @"total of %@ downloaded, at %@ per second", "results final download file transfer" ), MVPrettyFileSize( totalSize ), MVPrettyFileSize( avgRate )];
			else if( upCount ) str = [NSString stringWithFormat:NSLocalizedString( @"total of %@ uploaded, at %@ per second", "results final upload file transfer" ), MVPrettyFileSize( totalSize ), MVPrettyFileSize( avgRate )];
		}
		if( ( upCount + downCount ) == 1 && startDate ) {
			str = [str stringByAppendingString:@"\n"];
			if( avgRate > 0 ) str = [str stringByAppendingFormat:NSLocalizedString( @"%@ elapsed, %@ remaining", "time that has passed and time that remains on selected transfer" ), MVReadableTime( [startDate timeIntervalSince1970], YES ), MVReadableTime( [[NSDate date] timeIntervalSince1970] + ( ( totalSize - totalTransfered) / avgRate ), NO )];
			else str = [str stringByAppendingFormat:NSLocalizedString( @"%@ elapsed", "time that has passed on selected transfer" ), MVReadableTime( [startDate timeIntervalSince1970], YES )];
		}
	} else if( ! upCount && ! downCount ) {
		totalSize = 1;
		str = NSLocalizedString( @"no recent file transfers", "no files have been transfered or in the process of transfering" );
	}

	[transferStatus setStringValue:str];
	[progressBar setDoubleValue:totalTransfered];
	[progressBar setMaxValue:totalSize];
	[progressBar setNeedsDisplay:YES];
}

- (void) _changeUser:(NSNotification *) notification {
	NSEnumerator *enumerator = nil;
	NSDictionary *ninfo = [notification userInfo];
	NSMutableDictionary *info = nil;

	enumerator = [_transferStorage objectEnumerator];
	while( ( info = [enumerator nextObject] ) ) {
		if( [[info objectForKey:@"user"] isEqualToString:[ninfo objectForKey:@"oldNickname"]] && [[info objectForKey:@"connection"] isEqual:[notification object]] ) {
			[info setObject:[ninfo objectForKey:@"newNickname"] forKey:@"user"];
		}
	}

	[currentFiles reloadData];
}
@end
