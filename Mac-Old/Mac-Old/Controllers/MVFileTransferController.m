#import "MVFileTransferController.h"

#import "JVDetailCell.h"

static MVFileTransferController *sharedInstance = nil;

static NSString *MVToolbarStopItemIdentifier = @"MVToolbarStopItem";
static NSString *MVToolbarRevealItemIdentifier = @"MVToolbarRevealItem";
static NSString *MVToolbarClearItemIdentifier = @"MVToolbarClearItem";

NSString *MVPrettyFileSize( unsigned long long size ) {
	NSString *ret = nil;
	if( size == 0. ) ret = NSLocalizedString( @"Zero bytes", "no file size" );
	else if( size > 0. && size < 1024. ) ret = [NSString stringWithFormat:NSLocalizedString( @"%lu bytes", "file size measured in bytes" ), size];
	else if( size >= 1024. && size < pow( 1024., 2. ) ) ret = [NSString stringWithFormat:NSLocalizedString( @"%.1f KB", "file size measured in kilobytes" ), ( size / 1024. )];
	else if( size >= pow( 1024., 2. ) && size < pow( 1024., 3. ) ) ret = [NSString stringWithFormat:NSLocalizedString( @"%.2f MB", "file size measured in megabytes" ), ( size / pow( 1024., 2. ) )];
	else if( size >= pow( 1024., 3. ) && size < pow( 1024., 4. ) ) ret = [NSString stringWithFormat:NSLocalizedString( @"%.3f GB", "file size measured in gigabytes" ), ( size / pow( 1024., 3. ) )];
	else if( size >= pow( 1024., 4. ) ) ret = [NSString stringWithFormat:NSLocalizedString( @"%.4f TB", "file size measured in terabytes" ), ( size / pow( 1024., 4. ) )];
	return ret;
}

NSString *MVReadableTime( NSTimeInterval date, BOOL longFormat ) {
	NSTimeInterval secs = [[NSDate date] timeIntervalSince1970] - date;
	NSUInteger i = 0, stop = 0;
	NSDictionary *desc = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString( @"second", "singular second" ), [NSNumber numberWithUnsignedLong:1], NSLocalizedString( @"minute", "singular minute" ), [NSNumber numberWithUnsignedLong:60], NSLocalizedString( @"hour", "singular hour" ), [NSNumber numberWithUnsignedLong:3600], NSLocalizedString( @"day", "singular day" ), [NSNumber numberWithUnsignedLong:86400], NSLocalizedString( @"week", "singular week" ), [NSNumber numberWithUnsignedLong:604800], NSLocalizedString( @"month", "singular month" ), [NSNumber numberWithUnsignedLong:2628000], NSLocalizedString( @"year", "singular year" ), [NSNumber numberWithUnsignedLong:31536000], nil];
	NSDictionary *plural = [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString( @"seconds", "plural seconds" ), [NSNumber numberWithUnsignedLong:1], NSLocalizedString( @"minutes", "plural minutes" ), [NSNumber numberWithUnsignedLong:60], NSLocalizedString( @"hours", "plural hours" ), [NSNumber numberWithUnsignedLong:3600], NSLocalizedString( @"days", "plural days" ), [NSNumber numberWithUnsignedLong:86400], NSLocalizedString( @"weeks", "plural weeks" ), [NSNumber numberWithUnsignedLong:604800], NSLocalizedString( @"months", "plural months" ), [NSNumber numberWithUnsignedLong:2628000], NSLocalizedString( @"years", "plural years" ), [NSNumber numberWithUnsignedLong:31536000], nil];
	NSDictionary *use = nil;
	NSMutableArray *breaks = nil;
	NSUInteger val = 0.;
	NSString *retval = nil;

	if( secs < 0 ) secs *= -1;

	breaks = [[desc allKeys] mutableCopy];
	[breaks sortUsingSelector:@selector( compare: )];

	while( i < [breaks count] && secs >= [[breaks objectAtIndex:i] doubleValue] ) i++;
	if( i > 0 ) i--;
	stop = [[breaks objectAtIndex:i] unsignedIntValue];

	val = (NSUInteger) ( secs / (CGFloat) stop );
	use = ( val > 1 ? plural : desc );
	retval = [NSString stringWithFormat:@"%lu %@", (unsigned long)val, [use objectForKey:[NSNumber numberWithUnsignedLong:stop]]];
	if( longFormat && i > 0 ) {
		NSUInteger rest = (NSUInteger) ( (NSUInteger) secs % stop );
		stop = [[breaks objectAtIndex:--i] unsignedIntValue];
		rest = (NSUInteger) ( rest / (CGFloat) stop );
		if( rest > 0 ) {
			use = ( rest > 1 ? plural : desc );
			retval = [retval stringByAppendingFormat:@" %lu %@", (unsigned long)rest, [use objectForKey:[breaks objectAtIndex:i]]];
		}
	}

	return retval;
}

#pragma mark -

@interface MVFileTransferController (MVFileTransferControllerPrivate)
#pragma mark ChatCore File Transfer Support
- (void) _fileTransferError:(NSNotification *) notification;
- (void) _fileTransferStarted:(NSNotification *) notification;
- (void) _fileTransferFinished:(NSNotification *) notification;
- (void) _incomingFile:(NSNotification *) notification;
- (void) _incomingFileSheetDidEndWithReturnCode:(NSModalResponse) returnCode fileTransfer:(MVDownloadFileTransfer *) transfer;
- (void) _incomingFileSavePanelDidEnd:(NSSavePanel *) sheet returnCode:(NSInteger) returnCode fileTransfer:(MVDownloadFileTransfer *) transfer;
#pragma mark URL Web Download Support
- (void) _downloadFileSavePanelDidEnd:(NSSavePanel *) sheet returnCode:(NSInteger) returnCode contextInfo:(void *) contextInfo;
- (void) _openFile:(id) sender;
- (void) _updateProgress:(id) sender;
- (NSMutableDictionary *) _infoForTransferAtIndex:(NSUInteger) index;
- (void) _startUpdateTimerIfNeeded;
- (void) _stopUpdateTimerIfFinished;
@end

#pragma mark -

@implementation MVFileTransferController
+ (NSString *) userPreferredDownloadFolder {
	NSString *preferredDownloadFolder = [[NSUserDefaults standardUserDefaults] stringForKey:@"JVUserPreferredDownloadFolder"];

	if (!preferredDownloadFolder.length)
		return [@"~/Downloads" stringByExpandingTildeInPath];
	return preferredDownloadFolder;
}

+ (void) setUserPreferredDownloadFolder:(NSString *) path {
	[[NSUserDefaults standardUserDefaults] setObject:path forKey:@"JVUserPreferredDownloadFolder"];
}

#pragma mark -

+ (MVFileTransferController *) defaultController {
	if( ! sharedInstance ) {
		sharedInstance = [self alloc];
		sharedInstance = [sharedInstance initWithWindowNibName:@"MVFileTransfer"];
	}

	return sharedInstance;
}

#pragma mark -

- (id) initWithWindowNibName:(NSString *) windowNibName {
	if( ( self = [super initWithWindowNibName:windowNibName] ) ) {
		_transferStorage = [[NSMutableArray alloc] init];
		_calculationItems = [[NSMutableArray alloc] init];

		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _incomingFile: ) name:MVDownloadFileTransferOfferNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _fileTransferStarted: ) name:MVFileTransferStartedNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _fileTransferFinished: ) name:MVFileTransferFinishedNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _fileTransferError: ) name:MVFileTransferErrorOccurredNotification object:nil];

		NSRange range = NSRangeFromString( [[NSUserDefaults standardUserDefaults] stringForKey:@"JVFileTransferPortRange"] );
		[MVFileTransfer setFileTransferPortRange:range];

		BOOL autoOpen = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVAutoOpenTransferPorts"];
		[MVFileTransfer setAutoPortMappingEnabled:autoOpen];

		_safeFileExtentions = [[NSSet alloc] initWithObjects:@"jpg",@"jpeg",@"gif",@"png",@"tif",@"tiff",@"psd",@"pdf",@"txt",@"rtf",@"html",@"htm",@"swf",@"mp3",@"wma",@"wmv",@"ogg",@"ogm",@"mov",@"mpg",@"mpeg",@"m1v",@"m2v",@"mp4",@"avi",@"vob",@"avi",@"asx",@"asf",@"pls",@"m3u",@"rmp",@"aif",@"aiff",@"aifc",@"wav",@"wave",@"m4a",@"m4p",@"m4b",@"dmg",@"udif",@"ndif",@"dart",@"sparseimage",@"cdr",@"dvdr",@"iso",@"img",@"toast",@"rar",@"sit",@"sitx",@"bin",@"hqx",@"zip",@"gz",@"tgz",@"tar",@"bz",@"bz2",@"tbz",@"z",@"taz",@"uu",@"uue",@"colloquytranscript",@"torrent",nil];
		_updateTimer = nil;
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter chatCenter] removeObserver:self];
	if( self == sharedInstance ) {
		sharedInstance = nil;
		[_updateTimer invalidate];
	}

	[currentFiles setDataSource:nil];
	[currentFiles setDelegate:nil];

	if( [self isWindowLoaded] )
		[[[self window] toolbar] setDelegate:nil];

	_transferStorage = nil;
	_safeFileExtentions = nil;
	_calculationItems = nil;
	_updateTimer = nil;
}

- (void) windowDidLoad {
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"Transfers"];
	NSTableColumn *theColumn = nil;

	[(NSPanel *)[self window] setFloatingPanel:NO];
	[[self window] setHidesOnDeactivate:NO];
	[[self window] setResizeIncrements:NSMakeSize( 1, [currentFiles rowHeight] + [currentFiles intercellSpacing].height )];

	[currentFiles setVerticalMotionCanBeginDrag:NO];
	[currentFiles setDoubleAction:@selector( _openFile: )];
	[currentFiles setAutosaveName:@"Transfers"];
	[currentFiles setAutosaveTableColumns:YES];

	theColumn = [currentFiles tableColumnWithIdentifier:@"file"];
	JVDetailCell *prototypeCell = [JVDetailCell new];
	[prototypeCell setFont:[NSFont systemFontOfSize:11.]];
	[prototypeCell setLineBreakMode:NSLineBreakByTruncatingMiddle];
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
	[[self window] makeKeyAndOrderFront:nil];
}

- (IBAction) hideTransferManager:(id) sender {
	[[self window] orderOut:nil];
}

#pragma mark -

- (void) downloadFileAtURL:(NSURL *) url toLocalFile:(NSString *) path {
	WebDownload *download = [[WebDownload alloc] initWithRequest:[NSURLRequest requestWithURL:url] delegate:self];

	if( ! download ) {
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = NSLocalizedString( @"Invalid URL", "Invalid URL title" );
		alert.informativeText = NSLocalizedString( @"The download URL is either invalid or unsupported.", "Invalid URL message" );
		[alert beginSheetModalForWindow:[self window] completionHandler:nil];
		return;
	}

	[self showTransferManager:nil];

	if( path ) [download setDestination:path allowOverwrite:NO];

	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	[info setObject:[NSNumber numberWithUnsignedLongLong:0] forKey:@"transferred"];
	[info setObject:[NSNumber numberWithDouble:0.] forKey:@"rate"];
	[info setObject:[NSNumber numberWithUnsignedLongLong:0] forKey:@"size"];
	[info setObject:download forKey:@"controller"];
	[info setObject:url forKey:@"url"];

	if( path ) [info setObject:path forKey:@"path"];
	else [info setObject:[[url path] lastPathComponent] forKey:@"path"];

	[_transferStorage addObject:info];
	[currentFiles reloadData];
	[self showTransferManager:nil];
	[self _startUpdateTimerIfNeeded];
}

- (void) addFileTransfer:(MVFileTransfer *) transfer {
	NSParameterAssert( transfer != nil );

	NSMutableDictionary *info = nil;
	for( info in _transferStorage )
		if( [[info objectForKey:@"controller"] isEqualTo:transfer] )
			return;

	info = [NSMutableDictionary dictionary];
	[info setObject:transfer forKey:@"controller"];
	[info setObject:[NSNumber numberWithDouble:0.] forKey:@"rate"];
	[info setObject:[NSNumber numberWithUnsignedLong:[transfer status]] forKey:@"status"];
	[info setObject:[NSNumber numberWithUnsignedLongLong:[transfer finalSize]] forKey:@"size"];
	if( [transfer isDownload] ) [info setObject:[(MVDownloadFileTransfer *)transfer destination] forKey:@"path"];
	else if( [transfer isUpload] ) [info setObject:[(MVUploadFileTransfer *)transfer source] forKey:@"path"];

	[_transferStorage addObject:info];
	[currentFiles reloadData];
	[self showTransferManager:nil];
	[self _startUpdateTimerIfNeeded];
}

#pragma mark -

- (IBAction) stopSelectedTransfer:(id) sender {
	NSMutableDictionary *info = nil;
	if( [currentFiles selectedRow] != -1 ) {
		info = [self _infoForTransferAtIndex:[currentFiles selectedRow]];
		[[info objectForKey:@"controller"] cancel];
		[info setObject:[NSNumber numberWithUnsignedInt:MVFileTransferStoppedStatus] forKey:@"status"];
	}

	[currentFiles reloadData];
	[self _updateProgress:nil];
}

- (IBAction) clearFinishedTransfers:(id) sender {
	NSUInteger i = 0;
	NSDictionary *info = nil;
	if( [currentFiles selectedRow] == -1 ) {
		for( i = 0; i < [_transferStorage count]; ) {
			info = [self _infoForTransferAtIndex:i];
			NSUInteger status = [[info objectForKey:@"status"] unsignedIntValue];
			if( status == MVFileTransferDoneStatus || status == MVFileTransferErrorStatus || status == MVFileTransferStoppedStatus ) {
				[_calculationItems removeObject:info];
				[_transferStorage removeObject:info];
			} else i++;
		}
	} else if( [currentFiles numberOfSelectedRows] == 1 ) {
		info = [self _infoForTransferAtIndex:[currentFiles selectedRow]];
		NSUInteger status = [[info objectForKey:@"status"] unsignedIntValue];
		if( status == MVFileTransferDoneStatus || status == MVFileTransferErrorStatus || status == MVFileTransferStoppedStatus ) {
			[_calculationItems removeObject:info];
			[_transferStorage removeObject:info];
		}
	}

	[currentFiles reloadData];
	[self _updateProgress:nil];
	[self _stopUpdateTimerIfFinished];
}

- (IBAction) revealSelectedFile:(id) sender {
	if( [currentFiles numberOfSelectedRows] == 1 ) {
		NSDictionary *info = [self _infoForTransferAtIndex:[currentFiles selectedRow]];
		[[NSWorkspace sharedWorkspace] selectFile:[info objectForKey:@"path"] inFileViewerRootedAtPath:@""];
	}
}

#pragma mark -

- (IBAction) copy:(id) sender {
	NSMutableArray *array = [NSMutableArray array];
	NSMutableString *string = [NSMutableString string];

	[[NSPasteboard generalPasteboard] declareTypes:[NSArray arrayWithObjects:NSFilenamesPboardType,NSStringPboardType,nil] owner:self];

	[[currentFiles selectedRowIndexes] enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *stop) {
		[array addObject:[[self _infoForTransferAtIndex:i] objectForKey:@"path"]];
		[string appendString:[[[self _infoForTransferAtIndex:i] objectForKey:@"path"] lastPathComponent]];
		if ( ! ( [[self->currentFiles selectedRowIndexes] lastIndex] == i ) ) [string appendString:@"\n"];
	}];

	[[NSPasteboard generalPasteboard] setPropertyList:array forType:NSFilenamesPboardType];
	[[NSPasteboard generalPasteboard] setString:string forType:NSStringPboardType];
}
@end

#pragma mark -

@implementation MVFileTransferController (MVFileTransferControllerDelegate)
#pragma mark Table View Support
- (NSInteger) numberOfRowsInTableView:(NSTableView *) view {
	return [_transferStorage count];
}

- (id) tableView:(NSTableView *) view objectValueForTableColumn:(NSTableColumn *) column row:(NSInteger) row {
	if( [[column identifier] isEqual:@"file"] ) {
		NSString *path = [[self _infoForTransferAtIndex:row] objectForKey:@"path"];
		NSImage *fileIcon = [[NSWorkspace sharedWorkspace] iconForFileType:[path pathExtension]];
		[fileIcon setSize:NSMakeSize( 16., 16. )];
		return fileIcon;
	} else if( [[column identifier] isEqual:@"size"] ) {
		unsigned long long size = [[[self _infoForTransferAtIndex:row] objectForKey:@"size"] unsignedLongLongValue];
		return ( size ? MVPrettyFileSize( size ) : @"--" );
	} else if( [[column identifier] isEqual:@"user"] ) {
		NSString *ret = [[[self _infoForTransferAtIndex:row] objectForKey:@"user"] displayName];
		return ( ret ? ret : NSLocalizedString( @"n/a", "not applicable identifier" ) );
	}
	return nil;
}

- (void) tableView:(NSTableView *) view willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) column row:(NSInteger) row {
	if( [[column identifier] isEqual:@"file"] ) {
		NSString *path = [[self _infoForTransferAtIndex:row] objectForKey:@"path"];
		[cell setMainText:[[NSFileManager defaultManager] displayNameAtPath:path]];
	} else if( [[column identifier] isEqual:@"status"] ) {
		NSDictionary *info = [self _infoForTransferAtIndex:row];
		id controller = [info objectForKey:@"controller"];
		MVFileTransferStatus status = [[info objectForKey:@"status"] unsignedIntValue];
		NSString *imageName = @"pending";
		if( status == MVFileTransferErrorStatus ) imageName = @"error";
		else if( status == MVFileTransferStoppedStatus ) imageName = @"stopped";
		else if( status == MVFileTransferDoneStatus ) imageName = @"done";
		else if( status == MVFileTransferNormalStatus && [controller isKindOfClass:[MVUploadFileTransfer class]] ) imageName = @"upload";
		else if( status == MVFileTransferNormalStatus && ( [controller isKindOfClass:[MVDownloadFileTransfer class]] || [controller isKindOfClass:[WebDownload class]] ) ) imageName = @"download";
		[cell setImage:[NSImage imageNamed:imageName]];
	}
}

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	BOOL noneSelected = YES;

	if( [currentFiles selectedRow] != -1 ) noneSelected = NO;
	for( NSToolbarItem *item in [[[self window] toolbar] visibleItems] ) {
		if( [[item itemIdentifier] isEqual:MVToolbarStopItemIdentifier] ) {
			if( ! noneSelected && [currentFiles numberOfSelectedRows] == 1 && [[[self _infoForTransferAtIndex:[currentFiles selectedRow]] objectForKey:@"status"] unsignedIntValue] != MVFileTransferDoneStatus )
				[item setAction:@selector( stopSelectedTransfer: )];
			else [item setAction:NULL];
		} else if( [[item itemIdentifier] isEqual:MVToolbarRevealItemIdentifier] ) {
			if( ! noneSelected && [currentFiles numberOfSelectedRows] == 1 ) [item setAction:@selector( revealSelectedFile: )];
			else [item setAction:NULL];
		} else if( [[item itemIdentifier] isEqual:MVToolbarClearItemIdentifier] ) {
			if( ! noneSelected && [currentFiles numberOfSelectedRows] == 1 && [[[self _infoForTransferAtIndex:[currentFiles selectedRow]] objectForKey:@"status"] unsignedIntValue] != MVFileTransferNormalStatus && [[[self _infoForTransferAtIndex:[currentFiles selectedRow]] objectForKey:@"status"] unsignedIntValue] != MVFileTransferHoldingStatus )
				[item setAction:@selector( clearFinishedTransfers: )];
			else if( noneSelected ) [item setAction:@selector( clearFinishedTransfers: )];
			else [item setAction:NULL];
		}
	}

	[_calculationItems removeAllObjects];
	[[currentFiles selectedRowIndexes] enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
		[self->_calculationItems addObject:[self _infoForTransferAtIndex:index]];
	}];
}

- (BOOL) tableView:(NSTableView *) tableView writeRowsWithIndexes:(NSIndexSet *) rowIndexes toPasteboard:(NSPasteboard *) pboard {
	NSMutableArray *array = [NSMutableArray array];

	[pboard declareTypes:[NSArray arrayWithObjects:NSFilenamesPboardType,nil] owner:self];

	[rowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		NSString *path = [[self _infoForTransferAtIndex:idx] objectForKey:@"path"];
		if( path ) [array addObject:path];
	}];

	[pboard setPropertyList:array forType:NSFilenamesPboardType];
	return YES;
}

#pragma mark -
#pragma mark Toolbar Support

- (NSToolbarItem *) toolbar:(NSToolbar *) toolbar itemForItemIdentifier:(NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdent];

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
#pragma mark Save Panel Trickery

- (NSString *) panel:(id) sender userEnteredFilename:(NSString *) filename confirmed:(BOOL) confirmed {
	return ( confirmed ? [filename stringByAppendingString:@".colloquyFake"] : filename );
}

#pragma mark -
#pragma mark URL Web Download Support

- (void) download:(NSURLDownload *) download decideDestinationWithSuggestedFilename:(NSString *) filename {
	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVAskForTransferSaveLocation"] ) {
		NSString *path = [[[self class] userPreferredDownloadFolder] stringByAppendingPathComponent:filename];

		for( NSMutableDictionary *info in _transferStorage ) {
			if( [info objectForKey:@"controller"] == download ) {
				[info setObject:path forKey:@"path"];
				break;
			}
		}

		[self _downloadFileSavePanelDidEnd:nil returnCode:NSModalResponseOK contextInfo:(void *)download];
	} else {
		NSSavePanel *savePanel = [NSSavePanel savePanel];
		[savePanel setDirectoryURL:[NSURL fileURLWithPath:[[self class] userPreferredDownloadFolder] isDirectory:YES]];
		[savePanel setNameFieldStringValue:filename];
		[savePanel beginWithCompletionHandler:^(NSInteger result) {
			[self _downloadFileSavePanelDidEnd:savePanel returnCode:result contextInfo:(void *)download];
		}];
	}
}

- (void) download:(NSURLDownload *) download didReceiveResponse:(NSURLResponse *) response {
	for( NSMutableDictionary *info in _transferStorage ) {
		if( [info objectForKey:@"controller"] == download ) {
			[info setObject:[NSNumber numberWithUnsignedLongLong:0] forKey:@"transferred"];

			unsigned long size = [response expectedContentLength];
			if( (long)size == -1 ) size = 0;
			[info setObject:[NSNumber numberWithUnsignedLongLong:size] forKey:@"size"];

			[currentFiles reloadData];
			break;
		}
	}
}

- (NSWindow *) downloadWindowForAuthenticationSheet:(WebDownload *) download {
	return [self window];
}

- (void) download:(NSURLDownload *) download didReceiveDataOfLength:(NSUInteger) length {
	for( NSMutableDictionary *info in _transferStorage ) {
		if( [info objectForKey:@"controller"] == download ) {
			NSTimeInterval timeslice = [[info objectForKey:@"started"] timeIntervalSinceNow] * -1;
			unsigned long long transferred = [[info objectForKey:@"transferred"] unsignedLongLongValue] + length;

			[info setObject:[NSNumber numberWithUnsignedInt:MVFileTransferNormalStatus] forKey:@"status"];
			[info setObject:[NSNumber numberWithUnsignedLongLong:transferred] forKey:@"transferred"];

			if( transferred > [[info objectForKey:@"size"] unsignedLongLongValue] )
				[info setObject:[NSNumber numberWithUnsignedLongLong:transferred] forKey:@"size"];

			if( transferred != [[info objectForKey:@"size"] unsignedLongLongValue] )
				[info setObject:[NSNumber numberWithDouble:( transferred / timeslice )] forKey:@"rate"];

			if( ! [info objectForKey:@"started"] ) {
				[info setObject:[NSDate date] forKey:@"started"];
				[currentFiles reloadData];
			}

			break;
		}
	}
}

- (BOOL) download:(NSURLDownload *) download shouldDecodeSourceDataOfMIMEType:(NSString *) encodingType {
	return NO;
}

- (void) downloadDidFinish:(NSURLDownload *) download {
	for( NSMutableDictionary *info in [_transferStorage copy] ) {
		if( [info objectForKey:@"controller"] == download ) {
			[info setObject:[NSNumber numberWithUnsignedInt:MVFileTransferDoneStatus] forKey:@"status"];

			[[NSWorkspace sharedWorkspace] noteFileSystemChanged:[info objectForKey:@"path"]];

			if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVOpenSafeFiles"] && [_safeFileExtentions containsObject:[[[info objectForKey:@"path"] pathExtension] lowercaseString]] )
				[[NSWorkspace sharedWorkspace] openFile:[info objectForKey:@"path"] withApplication:nil andDeactivate:NO];

			if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVRemoveTransferredItems"] == 2 ) {
				[_calculationItems removeObject:info];
				[_transferStorage removeObject:info];
				[self _stopUpdateTimerIfFinished];
			}

			[currentFiles reloadData];
			break;
		}
	}
}

- (void) download:(NSURLDownload *) download didFailWithError:(NSError *) error {
	for( NSMutableDictionary *info in _transferStorage ) {
		if( [info objectForKey:@"controller"] == download ) {
			[info setObject:[NSNumber numberWithUnsignedInt:MVFileTransferErrorStatus] forKey:@"status"];
			[currentFiles reloadData];
			break;
		}
	}
}
@end

#pragma mark -

@implementation MVFileTransferController (MVFileTransferControllerPrivate)
#pragma mark ChatCore File Transfer Support
- (void) _fileTransferError:(NSNotification *) notification {
	[currentFiles reloadData];
}

- (void) _fileTransferStarted:(NSNotification *) notification {
	MVDownloadFileTransfer *transfer = [notification object];

	for( NSMutableDictionary *info in [_transferStorage copy] ){
		if( [[info objectForKey:@"controller"] isEqualTo:transfer] ) {
			if( [transfer startDate] ) [info setObject:[transfer startDate] forKey:@"startDate"];
			break;
		}
	}

	[currentFiles reloadData];
}

- (void) _fileTransferFinished:(NSNotification *) notification {
	MVFileTransfer *transfer = [notification object];

	for( NSMutableDictionary *info in [_transferStorage copy] ) {
		if( [[info objectForKey:@"controller"] isEqualTo:transfer] ) {
			if( [transfer isDownload] ) {
				NSString *path = [(MVDownloadFileTransfer *)transfer destination];

				[[NSWorkspace sharedWorkspace] noteFileSystemChanged:path];

				if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVOpenSafeFiles"] && [_safeFileExtentions containsObject:[[path pathExtension] lowercaseString]] )
					[[NSWorkspace sharedWorkspace] openFile:path withApplication:nil andDeactivate:NO];
			}

			if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVRemoveTransferredItems"] == 2 ) {
				[_calculationItems removeObject:info];
				[_transferStorage removeObject:info];
				[self _stopUpdateTimerIfFinished];
			}

			[currentFiles reloadData];
			break;
		}
	}
}

- (void) _incomingFile:(NSNotification *) notification {
	MVDownloadFileTransfer *transfer = [notification object];

	if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVAutoAcceptFilesFrom"] == 3 ) {
		[self _incomingFileSheetDidEndWithReturnCode:NSAlertFirstButtonReturn fileTransfer:transfer];
	} else if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVAutoAcceptFilesFrom"] == 2 ) {
//		JVBuddy *buddy = [[MVBuddyListController sharedBuddyList] buddyForNickname:[transfer user] onServer:[(MVChatConnection *)[transfer connection] server]];
//		if( buddy ) [self _incomingFileSheetDidEnd:nil returnCode:NSModalResponseOK contextInfo:(void *)[transfer retain]];
//		else
		// transfer is released when the sheet closes
		
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = NSLocalizedString( @"Incoming File Transfer", "new file transfer dialog title" );
		alert.informativeText = [NSString stringWithFormat:NSLocalizedString( @"A file named \"%@\" is being sent to you from %@. This file is %@ in size.", "new file transfer dialog message" ), [transfer originalFileName], [transfer user], MVPrettyFileSize( [transfer finalSize] )];
		alert.alertStyle = NSAlertStyleInformational;
		[alert addButtonWithTitle:NSLocalizedString( @"Accept", "accept button name" )];
		[alert addButtonWithTitle:NSLocalizedString( @"Refuse", "refuse button name" )];
		[alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse returnCode) {
			[self _incomingFileSheetDidEndWithReturnCode:returnCode fileTransfer:transfer];
		}];
	} else if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVAutoAcceptFilesFrom"] == 1 ) {
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = NSLocalizedString( @"Incoming File Transfer", "new file transfer dialog title" );
		alert.informativeText = [NSString stringWithFormat:NSLocalizedString( @"A file named \"%@\" is being sent to you from %@. This file is %@ in size.", "new file transfer dialog message" ), [transfer originalFileName], [transfer user], MVPrettyFileSize( [transfer finalSize] )];
		alert.alertStyle = NSAlertStyleInformational;
		[alert addButtonWithTitle:NSLocalizedString( @"Accept", "accept button name" )];
		[alert addButtonWithTitle:NSLocalizedString( @"Refuse", "refuse button name" )];
		[alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse returnCode) {
			[self _incomingFileSheetDidEndWithReturnCode:returnCode fileTransfer:transfer];
		}];
	}
}

- (void) _incomingFileSheetDidEndWithReturnCode:(NSModalResponse) returnCode fileTransfer:(MVDownloadFileTransfer *) transfer {
	if( returnCode == NSAlertFirstButtonReturn ) {
		if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVAskForTransferSaveLocation"] ) {
			NSString *path = [[[self class] userPreferredDownloadFolder] stringByAppendingPathComponent:[transfer originalFileName]];
			[transfer setDestination:path renameIfFileExists:NO];
			[self _incomingFileSavePanelDidEnd:nil returnCode:NSModalResponseOK fileTransfer:transfer];
		} else {
			NSSavePanel *savePanel = [NSSavePanel savePanel];
			[savePanel setDelegate:self];
			[savePanel setDirectoryURL:[NSURL fileURLWithPath:[[self class] userPreferredDownloadFolder] isDirectory:YES]];
			[savePanel beginWithCompletionHandler:^(NSModalResponse result) {
				[self _incomingFileSavePanelDidEnd:savePanel returnCode:result fileTransfer:transfer];
			}];
		}
	} else [transfer reject];
}

- (void) _incomingFileSavePanelDidEnd:(NSSavePanel *) sheet returnCode:(NSModalResponse) returnCode fileTransfer:(MVDownloadFileTransfer *) transfer {
	[sheet setDelegate:nil];

	if( returnCode == NSModalResponseOK ) {
		NSURL *fileURL = [sheet URL];
		NSString *filename = ( [[fileURL pathExtension] hasSuffix:@"colloquyFake"] ? [[fileURL path] stringByDeletingPathExtension] : [fileURL path] );
		if( ! filename ) filename = [transfer destination];
		NSNumber *size = [[[NSFileManager defaultManager] attributesOfItemAtPath:filename error:nil] objectForKey:NSFileSize];
		BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:filename];
		BOOL resumePossible = ( fileExists && [size unsignedLongLongValue] < [transfer finalSize] ? YES : NO );
		NSModalResponse response = NSAlertFirstButtonReturn;

		if( resumePossible ) {
			if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVFileExists"] == 1 ) response = NSAlertFirstButtonReturn; // auto resume
			else if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVFileExists"] == 2 ) response = NSAlertSecondButtonReturn; // auto cancel
			else if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVFileExists"] == 3 ) { // auto overwrite
				resumePossible = NO;
				response = NSAlertFirstButtonReturn;
			} else {
				NSAlert *alert = [[NSAlert alloc] init];
				alert.messageText = NSLocalizedString( @"Save", "save dialog title" );
				alert.informativeText = [NSString stringWithFormat:NSLocalizedString( @"The file %@ in %@ already exists. Would you like to resume from where a previous transfer stopped or replace it?", "replace or resume transfer save dialog message" ), [[NSFileManager defaultManager] displayNameAtPath:filename], [filename stringByDeletingLastPathComponent]];
				alert.alertStyle = NSAlertStyleWarning;
				[alert addButtonWithTitle:NSLocalizedString( @"Resume", "resume button name" )];
				[alert addButtonWithTitle:( sheet ? NSLocalizedString( @"Cancel", "cancel button" ) : NSLocalizedString( @"Save As...", "save as button name" ) )];
				[alert addButtonWithTitle:NSLocalizedString( @"Replace", "replace button name" )];
				response = [alert runModal];
			}
		} else if( fileExists ) {
			NSAlert *alert = [[NSAlert alloc] init];
			alert.messageText = NSLocalizedString( @"Save", "save dialog title" );
			alert.informativeText = [NSString stringWithFormat:NSLocalizedString( @"The file %@ in %@ already exists and can't be resumed. Replace it?", "replace transfer save dialog message" ), [[NSFileManager defaultManager] displayNameAtPath:filename], [filename stringByDeletingLastPathComponent]];
			alert.alertStyle = NSAlertStyleWarning;
			[alert addButtonWithTitle:NSLocalizedString( @"Replace", "replace button name" )];
			[alert addButtonWithTitle:( sheet ? NSLocalizedString( @"Cancel", "cancel button" ) : NSLocalizedString( @"Save As...", "save as button name" ) )];
			response = [alert runModal];
		}

		if( response == NSAlertSecondButtonReturn ) {
			NSSavePanel *savePanel = [NSSavePanel savePanel];
			[sheet close];
			[savePanel setDelegate:self];
			[savePanel setDirectoryURL:[sheet directoryURL]];
			[savePanel beginWithCompletionHandler:^(NSInteger saveResult) {
				[self _incomingFileSavePanelDidEnd:savePanel returnCode:saveResult fileTransfer:transfer];
			}];
		} else {
			BOOL resume = ( resumePossible && response == NSAlertFirstButtonReturn );
			[transfer setDestination:filename renameIfFileExists:NO];
			[transfer acceptByResumingIfPossible:resume];
			[self addFileTransfer:transfer];
		}
	} else [transfer reject];
}

#pragma mark -
#pragma mark URL Web Download Support

- (void) _downloadFileSavePanelDidEnd:(NSSavePanel *) sheet returnCode:(NSInteger) returnCode contextInfo:(void *) contextInfo {
	WebDownload *download = (__bridge WebDownload *)contextInfo;
	[sheet setDelegate:nil];

	if( returnCode == NSModalResponseOK ) {
		NSMutableDictionary *info = nil;
		for( info in _transferStorage ) {
			if( [info objectForKey:@"controller"] == download ) {
				if( sheet ) [info setObject:[[sheet URL] path] forKey:@"path"];
				break;
			}
		}

		[download setDestination:[info objectForKey:@"path"] allowOverwrite:YES];
	} else {
		[download cancel];

		for( NSMutableDictionary *info in _transferStorage ) {
			if( [info objectForKey:@"controller"] == download ) {
				[info setObject:[NSNumber numberWithUnsignedInt:MVFileTransferStoppedStatus] forKey:@"status"];
				break;
			}
		}
	}
}

- (void) _openFile:(id) sender {
	NSDictionary *info = nil;
	NSIndexSet *selectedRowIndexSet = [currentFiles selectedRowIndexes];
	NSUInteger currentIndex = [selectedRowIndexSet firstIndex];

	while (currentIndex != NSNotFound) {
		info = [self _infoForTransferAtIndex:[currentFiles selectedRow]];
		[[NSWorkspace sharedWorkspace] openFile:[info objectForKey:@"path"]];

		currentIndex = [selectedRowIndexSet indexGreaterThanIndex:currentIndex];
	}
}

- (void) _updateProgress:(id) sender {
	NSString *str = nil;
	unsigned long long totalSizeUp = 0, totalTransferredUp = 0, totalTransferred = 0, totalSize = 0;
	unsigned long long totalSizeDown = 0, totalTransferredDown = 0;
	double upRate = 0., downRate = 0., avgRate = 0.;
	unsigned upCount = 0, downCount = 0;

	if( sender && ! [[self window] isVisible] ) return;

	id enumerateThrough = nil;
	if( [_calculationItems count] ) enumerateThrough = _calculationItems;
	else enumerateThrough = _transferStorage;
	for( NSMutableDictionary *info in enumerateThrough) {
		id controller = [info objectForKey:@"controller"];
		if( [controller isKindOfClass:[MVFileTransfer class]] ) {
			MVFileTransfer *transferController = controller;
			NSTimeInterval timeslice = [[transferController startDate] timeIntervalSinceNow] * -1;
			double currentRate = 0.;

			if( ( [transferController status] == MVFileTransferNormalStatus ) && ( [transferController transferred] != [transferController finalSize] ) ) {
				currentRate = ( ( [transferController transferred] - [transferController startOffset] ) / timeslice );
				[info setObject:[NSNumber numberWithDouble:currentRate] forKey:@"rate"];
			} else currentRate = [[info valueForKey:@"rate"] doubleValue];

			[info setObject:[NSNumber numberWithUnsignedInt:[transferController status]] forKey:@"status"];

			if( [transferController isUpload] ) {
				totalSizeUp += [transferController finalSize];
				totalTransferredUp += [transferController transferred];
				upRate += currentRate;
				upCount++;
			} else {
				totalSizeDown += [transferController finalSize];
				totalTransferredDown += [transferController transferred];
				downRate += currentRate;
				downCount++;
			}
		} else if( [controller isKindOfClass:[WebDownload class]] ) {
			totalSizeDown += [[info objectForKey:@"size"] unsignedLongValue];
			totalTransferredDown += [[info objectForKey:@"transferred"] unsignedLongValue];
			downRate += [[info objectForKey:@"rate"] doubleValue];
			downCount++;
		}
	}

	totalTransferred = totalTransferredDown + totalTransferredUp;
	totalSize = totalSizeDown + totalSizeUp;
	if( upCount && downCount ) {
		upRate = upRate / (CGFloat) upCount;
		if( ! totalTransferredUp || ! totalSizeUp ) {
			str = NSLocalizedString( @"nothing uploaded yet", "status of pending upload file transfer" );
		} else if( totalSizeUp != totalTransferredUp ) {
			str = [NSString stringWithFormat:NSLocalizedString( @"%@ of %@ uploaded, at %@ per second", "status of current upload file transfer" ), MVPrettyFileSize( totalTransferredUp ), MVPrettyFileSize( totalSizeUp ), MVPrettyFileSize( upRate )];
		} else if( totalTransferredUp >= totalSizeUp ) {
			str = [NSString stringWithFormat:NSLocalizedString( @"total of %@ uploaded, at %@ per second", "results final upload file transfer" ), MVPrettyFileSize( totalSizeUp ), MVPrettyFileSize( upRate )];
		}
		str = [str stringByAppendingString:@"\n"];
		downRate = downRate / (CGFloat) downCount;
		if( ! totalTransferredDown || ! totalSizeDown ) {
			str = [str stringByAppendingString:NSLocalizedString( @"nothing downloaded yet", "status of pending download file transfer" )];
		} else if( totalSizeDown != totalTransferredDown ) {
			str = [str stringByAppendingFormat:NSLocalizedString( @"%@ of %@ downloaded, at %@ per second", "status of current download file transfer" ), MVPrettyFileSize( totalTransferredDown ), MVPrettyFileSize( totalSizeDown ), MVPrettyFileSize( downRate )];
		} else if( totalTransferredDown >= totalSizeDown ) {
			str = [str stringByAppendingFormat:NSLocalizedString( @"total of %@ downloaded, at %@ per second", "results final download file transfer" ), MVPrettyFileSize( totalSizeDown ), MVPrettyFileSize( downRate )];
		}
	} else if( upCount || downCount ) {
		avgRate = ( upRate + downRate ) / ( (CGFloat) upCount + (CGFloat) downCount );
		if( ! totalTransferred || ! totalSize ) {
			totalSize = 1;
			if( downCount ) str = NSLocalizedString( @"nothing downloaded yet", "status of pending download file transfer" );
			else if( upCount ) str = NSLocalizedString( @"nothing uploaded yet", "status of pending upload file transfer" );
		} else if( totalSize != totalTransferred ) {
			if( downCount ) str = [NSString stringWithFormat:NSLocalizedString( @"%@ of %@ downloaded, at %@ per second", "status of current download file transfer" ), MVPrettyFileSize( totalTransferred ), MVPrettyFileSize( totalSize ), MVPrettyFileSize( avgRate )];
			else if( upCount ) str = [NSString stringWithFormat:NSLocalizedString( @"%@ of %@ uploaded, at %@ per second", "status of current upload file transfer" ), MVPrettyFileSize( totalTransferred ), MVPrettyFileSize( totalSize ), MVPrettyFileSize( avgRate )];
		} else if( totalTransferred >= totalSize ) {
			if( downCount ) str = [NSString stringWithFormat:NSLocalizedString( @"total of %@ downloaded, at %@ per second", "results final download file transfer" ), MVPrettyFileSize( totalSize ), MVPrettyFileSize( avgRate )];
			else if( upCount ) str = [NSString stringWithFormat:NSLocalizedString( @"total of %@ uploaded, at %@ per second", "results final upload file transfer" ), MVPrettyFileSize( totalSize ), MVPrettyFileSize( avgRate )];
		}
		if( ( upCount + downCount ) == 1 ) {
			NSDate *startDate = nil;
			NSDictionary *info = nil;

			if( [_calculationItems count] ) info = [_calculationItems lastObject];
			else info = [_transferStorage lastObject];

			if( [[info objectForKey:@"controller"] isKindOfClass:[MVFileTransfer class]] )
				startDate = [[info objectForKey:@"controller"] startDate];
			else startDate = [info objectForKey:@"started"];

			if( startDate && [[info objectForKey:@"status"] unsignedIntValue] == MVFileTransferNormalStatus ) {
				str = [str stringByAppendingString:@"\n"];
				if( avgRate > 0 ) str = [str stringByAppendingFormat:NSLocalizedString( @"%@ elapsed, %@ remaining", "time that has passed and time that remains on selected transfer" ), MVReadableTime( [startDate timeIntervalSince1970], YES ), MVReadableTime( [[NSDate date] timeIntervalSince1970] + ( ( totalSize - totalTransferred) / avgRate ), NO )];
				else if( startDate ) str = [str stringByAppendingFormat:NSLocalizedString( @"%@ elapsed", "time that has passed on selected transfer" ), MVReadableTime( [startDate timeIntervalSince1970], YES )];
			}
		}
	} else if( ! upCount && ! downCount ) {
		totalSize = 1;
		str = NSLocalizedString( @"no recent file transfers", "no files have been transferred or in the process of transfering" );
	}

	[transferStatus setStringValue:str];
	[progressBar setDoubleValue:totalTransferred];
	[progressBar setMaxValue:totalSize];
	[progressBar setNeedsDisplay:YES];
}

- (NSMutableDictionary *) _infoForTransferAtIndex:(NSUInteger) index {
	NSMutableDictionary *info = [_transferStorage objectAtIndex:index];

	if( [[info objectForKey:@"controller"] isKindOfClass:[MVFileTransfer class]] ) {
		MVFileTransfer *transfer = [info objectForKey:@"controller"];
		[info setObject:[NSNumber numberWithUnsignedInt:[transfer status]] forKey:@"status"];
		[info setObject:[transfer user] forKey:@"user"];
	}

	return info;
}

- (void) _startUpdateTimerIfNeeded {
	if( _updateTimer ) return;
	_updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector( _updateProgress: ) userInfo:nil repeats:YES];
}

- (void) _stopUpdateTimerIfFinished {
	if( ! _updateTimer || [_calculationItems count] ) return;
	[_updateTimer invalidate];
	_updateTimer = nil;
}
@end
