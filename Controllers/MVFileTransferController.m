#import "MVFileTransferController.h"

#import "JVDetailCell.h"

static MVFileTransferController *sharedInstance = nil;

static NSString *MVToolbarStopItemIdentifier = @"MVToolbarStopItem";
static NSString *MVToolbarRevealItemIdentifier = @"MVToolbarRevealItem";
static NSString *MVToolbarClearItemIdentifier = @"MVToolbarClearItem";

NSString *MVPrettyFileSize( unsigned long long size ) {
	NSString *ret = [NSByteCountFormatter stringFromByteCount:size countStyle:NSByteCountFormatterCountStyleFile];
	if (ret != nil) {
		return ret;
	}
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
	NSDictionary *desc = @{@1UL: NSLocalizedString( @"second", "singular second" ), @60UL: NSLocalizedString( @"minute", "singular minute" ), @3600UL: NSLocalizedString( @"hour", "singular hour" ), @86400UL: NSLocalizedString( @"day", "singular day" ), @604800UL: NSLocalizedString( @"week", "singular week" ), @2628000UL: NSLocalizedString( @"month", "singular month" ), @31536000UL: NSLocalizedString( @"year", "singular year" )};
	NSDictionary *plural = @{@1UL: NSLocalizedString( @"seconds", "plural seconds" ), @60UL: NSLocalizedString( @"minutes", "plural minutes" ), @3600UL: NSLocalizedString( @"hours", "plural hours" ), @86400UL: NSLocalizedString( @"days", "plural days" ), @604800UL: NSLocalizedString( @"weeks", "plural weeks" ), @2628000UL: NSLocalizedString( @"months", "plural months" ), @31536000UL: NSLocalizedString( @"years", "plural years" )};
	NSDictionary *use = nil;
	NSMutableArray *breaks = nil;
	NSUInteger val = 0.;
	NSString *retval = nil;

	if( secs < 0 ) secs *= -1;

	breaks = [[desc allKeys] mutableCopy];
	[breaks sortUsingSelector:@selector( compare: )];

	while( i < [breaks count] && secs >= [breaks[i] doubleValue] ) i++;
	if( i > 0 ) i--;
	stop = [breaks[i] unsignedIntValue];

	val = (NSUInteger) ( secs / (float) stop );
	use = ( val > 1 ? plural : desc );
	retval = [NSString stringWithFormat:@"%lu %@", (unsigned long)val, [use objectForKey:[NSNumber numberWithUnsignedLong:stop]]];
	if( longFormat && i > 0 ) {
		NSUInteger rest = (NSUInteger) ( (NSUInteger) secs % stop );
		stop = [breaks[--i] unsignedIntValue];
		rest = (NSUInteger) ( rest / (float) stop );
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
- (void) _incomingFileSheetDidEnd:(NSWindow *) sheet returnCode:(NSInteger) returnCode contextInfo:(void *) contextInfo;
- (void) _incomingFileSavePanelDidEnd:(NSSavePanel *) sheet returnCode:(NSInteger) returnCode contextInfo:(void *) contextInfo;
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
		return [NSHomeDirectory() stringByAppendingPathComponent:@"Downloads"];
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

- (instancetype) initWithWindowNibName:(NSString *) windowNibName {
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
		NSBeginAlertSheet( NSLocalizedString( @"Invalid URL", "Invalid URL title" ), nil, nil, nil, [self window], nil, nil, nil, nil, NSLocalizedString( @"The download URL is either invalid or unsupported.", "Invalid URL message" ), nil );
		return;
	}

	[self showTransferManager:nil];

	if( path ) [download setDestination:path allowOverwrite:NO];

	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	info[@"transferred"] = @0ULL;
	info[@"rate"] = @0.;
	info[@"size"] = @0ULL;
	info[@"controller"] = download;
	info[@"url"] = url;

	if( path ) info[@"path"] = path;
	else info[@"path"] = [[url path] lastPathComponent];

	[_transferStorage addObject:info];
	[currentFiles reloadData];
	[self showTransferManager:nil];
	[self _startUpdateTimerIfNeeded];
}

- (void) addFileTransfer:(MVFileTransfer *) transfer {
	NSParameterAssert( transfer != nil );

	NSMutableDictionary *info = nil;
	for( info in _transferStorage )
		if( [info[@"controller"] isEqualTo:transfer] )
			return;

	info = [NSMutableDictionary dictionary];
	info[@"controller"] = transfer;
	info[@"rate"] = @0.;
	info[@"status"] = @([transfer status]);
	info[@"size"] = @([transfer finalSize]);
	if( [transfer isDownload] ) info[@"path"] = [(MVDownloadFileTransfer *)transfer destination];
	else if( [transfer isUpload] ) info[@"path"] = [(MVUploadFileTransfer *)transfer source];

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
		[info[@"controller"] cancel];
		info[@"status"] = @(MVFileTransferStoppedStatus);
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
			NSUInteger status = [info[@"status"] unsignedIntValue];
			if( status == MVFileTransferDoneStatus || status == MVFileTransferErrorStatus || status == MVFileTransferStoppedStatus ) {
				[_calculationItems removeObject:info];
				[_transferStorage removeObject:info];
			} else i++;
		}
	} else if( [currentFiles numberOfSelectedRows] == 1 ) {
		info = [self _infoForTransferAtIndex:[currentFiles selectedRow]];
		NSUInteger status = [info[@"status"] unsignedIntValue];
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
		[[NSWorkspace sharedWorkspace] selectFile:info[@"path"] inFileViewerRootedAtPath:@""];
	}
}

#pragma mark -

- (IBAction) copy:(id) sender {
	NSMutableArray *array = [NSMutableArray array];
	NSMutableString *string = [NSMutableString string];

	[[NSPasteboard generalPasteboard] declareTypes:@[NSFilenamesPboardType,NSStringPboardType] owner:self];

	[[currentFiles selectedRowIndexes] enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *stop) {
		[array addObject:[self _infoForTransferAtIndex:i][@"path"]];
		[string appendString:[[self _infoForTransferAtIndex:i][@"path"] lastPathComponent]];
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
		NSString *path = [self _infoForTransferAtIndex:row][@"path"];
		NSImage *fileIcon = [[NSWorkspace sharedWorkspace] iconForFileType:[path pathExtension]];
		[fileIcon setSize:NSMakeSize( 16., 16. )];
		return fileIcon;
	} else if( [[column identifier] isEqual:@"size"] ) {
		unsigned long long size = [[self _infoForTransferAtIndex:row][@"size"] unsignedLongLongValue];
		return ( size ? MVPrettyFileSize( size ) : @"--" );
	} else if( [[column identifier] isEqual:@"user"] ) {
		NSString *ret = [[self _infoForTransferAtIndex:row][@"user"] displayName];
		return ( ret ? ret : NSLocalizedString( @"n/a", "not applicable identifier" ) );
	}
	return nil;
}

- (void) tableView:(NSTableView *) view willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) column row:(NSInteger) row {
	if( [[column identifier] isEqual:@"file"] ) {
		NSString *path = [self _infoForTransferAtIndex:row][@"path"];
		[cell setMainText:[[NSFileManager defaultManager] displayNameAtPath:path]];
	} else if( [[column identifier] isEqual:@"status"] ) {
		NSDictionary *info = [self _infoForTransferAtIndex:row];
		id controller = info[@"controller"];
		MVFileTransferStatus status = [info[@"status"] unsignedIntValue];
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
			if( ! noneSelected && [currentFiles numberOfSelectedRows] == 1 && [[self _infoForTransferAtIndex:[currentFiles selectedRow]][@"status"] unsignedIntValue] != MVFileTransferDoneStatus )
				[item setAction:@selector( stopSelectedTransfer: )];
			else [item setAction:NULL];
		} else if( [[item itemIdentifier] isEqual:MVToolbarRevealItemIdentifier] ) {
			if( ! noneSelected && [currentFiles numberOfSelectedRows] == 1 ) [item setAction:@selector( revealSelectedFile: )];
			else [item setAction:NULL];
		} else if( [[item itemIdentifier] isEqual:MVToolbarClearItemIdentifier] ) {
			if( ! noneSelected && [currentFiles numberOfSelectedRows] == 1 && [[self _infoForTransferAtIndex:[currentFiles selectedRow]][@"status"] unsignedIntValue] != MVFileTransferNormalStatus && [[self _infoForTransferAtIndex:[currentFiles selectedRow]][@"status"] unsignedIntValue] != MVFileTransferHoldingStatus )
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

	[pboard declareTypes:@[NSFilenamesPboardType] owner:self];

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
		[toolbarItem setImage:[[NSWorkspace sharedWorkspace] iconForFileType: NSFileTypeForHFSTypeCode(kAlertStopIcon)]];

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
	return @[MVToolbarStopItemIdentifier, MVToolbarClearItemIdentifier,
		NSToolbarSeparatorItemIdentifier, MVToolbarRevealItemIdentifier];
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar {
	return @[MVToolbarStopItemIdentifier, MVToolbarClearItemIdentifier,
		MVToolbarRevealItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier];
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
			if( info[@"controller"] == download ) {
				info[@"path"] = path;
				break;
			}
		}

		[self _downloadFileSavePanelDidEnd:nil returnCode:NSOKButton contextInfo:(void *)download];
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
		if( info[@"controller"] == download ) {
			info[@"transferred"] = @0ULL;

			unsigned long long size = [response expectedContentLength];
			if( (long)size == -1 ) size = 0;
			info[@"size"] = @(size);

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
		if( info[@"controller"] == download ) {
			NSTimeInterval timeslice = [info[@"started"] timeIntervalSinceNow] * -1;
			unsigned long long transferred = [info[@"transferred"] unsignedLongLongValue] + length;

			info[@"status"] = @(MVFileTransferNormalStatus);
			info[@"transferred"] = @(transferred);

			if( transferred > [info[@"size"] unsignedLongLongValue] )
				info[@"size"] = @(transferred);

			if( transferred != [info[@"size"] unsignedLongLongValue] )
				info[@"rate"] = @( transferred / timeslice );

			if( ! info[@"started"] ) {
				info[@"started"] = [NSDate date];
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
		if( info[@"controller"] == download ) {
			info[@"status"] = @(MVFileTransferDoneStatus);

			[[NSWorkspace sharedWorkspace] noteFileSystemChanged:info[@"path"]];

			if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVOpenSafeFiles"] && [_safeFileExtentions containsObject:[[info[@"path"] pathExtension] lowercaseString]] )
				[[NSWorkspace sharedWorkspace] openFile:info[@"path"] withApplication:nil andDeactivate:NO];

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
		if( info[@"controller"] == download ) {
			info[@"status"] = @(MVFileTransferErrorStatus);
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
		if( [info[@"controller"] isEqualTo:transfer] ) {
			if( [transfer startDate] ) info[@"startDate"] = [transfer startDate];
			break;
		}
	}

	[currentFiles reloadData];
}

- (void) _fileTransferFinished:(NSNotification *) notification {
	MVFileTransfer *transfer = [notification object];

	for( NSMutableDictionary *info in [_transferStorage copy] ) {
		if( [info[@"controller"] isEqualTo:transfer] ) {
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
		[self _incomingFileSheetDidEnd:nil returnCode:NSOKButton contextInfo:(void *)transfer];
	} else if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVAutoAcceptFilesFrom"] == 2 ) {
//		JVBuddy *buddy = [[MVBuddyListController sharedBuddyList] buddyForNickname:[transfer user] onServer:[(MVChatConnection *)[transfer connection] server]];
//		if( buddy ) [self _incomingFileSheetDidEnd:nil returnCode:NSOKButton contextInfo:(void *)[transfer retain]];
//		else
		// transfer is released when the sheet closes
		NSBeginInformationalAlertSheet( NSLocalizedString( @"Incoming File Transfer", "new file transfer dialog title" ), NSLocalizedString( @"Accept", "accept button name" ), NSLocalizedString( @"Refuse", "refuse button name" ), nil, nil, self, @selector( _incomingFileSheetDidEnd:returnCode:contextInfo: ), NULL, (void *)CFBridgingRetain(transfer), NSLocalizedString( @"A file named \"%@\" is being sent to you from %@. This file is %@ in size.", "new file transfer dialog message" ), [transfer originalFileName], [transfer user], MVPrettyFileSize( [transfer finalSize] ) );
	} else if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVAutoAcceptFilesFrom"] == 1 ) {
		NSBeginInformationalAlertSheet( NSLocalizedString( @"Incoming File Transfer", "new file transfer dialog title" ), NSLocalizedString( @"Accept", "accept button name" ), NSLocalizedString( @"Refuse", "refuse button name" ), nil, nil, self, @selector( _incomingFileSheetDidEnd:returnCode:contextInfo: ), NULL, (void *)CFBridgingRetain(transfer), NSLocalizedString( @"A file named \"%@\" is being sent to you from %@. This file is %@ in size.", "new file transfer dialog message" ), [transfer originalFileName], [transfer user], MVPrettyFileSize( [transfer finalSize] ) );
	}
}

- (void) _incomingFileSheetDidEnd:(NSWindow *) sheet returnCode:(NSInteger) returnCode contextInfo:(void *) contextInfo {
	MVDownloadFileTransfer *transfer = (__bridge MVDownloadFileTransfer *)contextInfo;

	if( returnCode == NSOKButton ) {
		if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVAskForTransferSaveLocation"] ) {
			NSString *path = [[[self class] userPreferredDownloadFolder] stringByAppendingPathComponent:[transfer originalFileName]];
			[sheet close];
			[transfer setDestination:path renameIfFileExists:NO];
			[self _incomingFileSavePanelDidEnd:nil returnCode:NSOKButton contextInfo:(void *)transfer];
		} else {
			NSSavePanel *savePanel = [NSSavePanel savePanel];
			[sheet close];
			[savePanel setDelegate:self];
			[savePanel setDirectoryURL:[NSURL fileURLWithPath:[[self class] userPreferredDownloadFolder] isDirectory:YES]];
			[savePanel beginWithCompletionHandler:^(NSInteger result) {
				[self _incomingFileSavePanelDidEnd:savePanel returnCode:result contextInfo:(void *)transfer];
			}];
		}
	} else [transfer reject];
}

- (void) _incomingFileSavePanelDidEnd:(NSSavePanel *) sheet returnCode:(NSInteger) returnCode contextInfo:(void *) contextInfo {
	MVDownloadFileTransfer *transfer = (__bridge MVDownloadFileTransfer *)contextInfo;
	[sheet setDelegate:nil];

	if( returnCode == NSOKButton ) {
		NSURL *fileURL = [sheet URL];
		NSString *filename = ( [[fileURL pathExtension] hasSuffix:@"colloquyFake"] ? [[fileURL path] stringByDeletingPathExtension] : [fileURL path] );
		if( ! filename ) filename = [transfer destination];
		NSNumber *size = [[NSFileManager defaultManager] attributesOfItemAtPath:filename error:nil][NSFileSize];
		BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:filename];
		BOOL resumePossible = ( fileExists && [size unsignedLongLongValue] < [transfer finalSize] ? YES : NO );
		NSInteger result = NSOKButton;

		if( resumePossible ) {
			if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVFileExists"] == 1 ) result = NSOKButton; // auto resume
			else if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVFileExists"] == 2 ) result = NSCancelButton; // auto cancel
			else if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVFileExists"] == 3 ) { // auto overwrite
				resumePossible = NO;
				result = NSOKButton;
			} else result = NSRunAlertPanel( NSLocalizedString( @"Save", "save dialog title" ), NSLocalizedString( @"The file %@ in %@ already exists. Would you like to resume from where a previous transfer stopped or replace it?", "replace or resume transfer save dialog message" ), NSLocalizedString( @"Resume", "resume button name" ), ( sheet ? NSLocalizedString( @"Cancel", "cancel button" ) : NSLocalizedString( @"Save As...", "save as button name" ) ), NSLocalizedString( @"Replace", "replace button name" ), [[NSFileManager defaultManager] displayNameAtPath:filename], [filename stringByDeletingLastPathComponent] );
		} else if( fileExists ) result = NSRunAlertPanel( NSLocalizedString( @"Save", "save dialog title" ), NSLocalizedString( @"The file %@ in %@ already exists and can't be resumed. Replace it?", "replace transfer save dialog message" ), NSLocalizedString( @"Replace", "replace button name" ), ( sheet ? NSLocalizedString( @"Cancel", "cancel button" ) : NSLocalizedString( @"Save As...", "save as button name" ) ), nil, [[NSFileManager defaultManager] displayNameAtPath:filename], [filename stringByDeletingLastPathComponent] );

		if( result == NSCancelButton ) {
			NSSavePanel *savePanel = [NSSavePanel savePanel];
			[sheet close];
			[savePanel setDelegate:self];
			[savePanel setDirectoryURL:[sheet directoryURL]];
			[savePanel beginWithCompletionHandler:^(NSInteger result) {
				[self _incomingFileSavePanelDidEnd:savePanel returnCode:result contextInfo:(void *)transfer];
			}];
		} else {
			BOOL resume = ( resumePossible && result == NSOKButton );
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

	if( returnCode == NSOKButton ) {
		NSMutableDictionary *info = nil;
		for( info in _transferStorage ) {
			if( info[@"controller"] == download ) {
				if( sheet ) info[@"path"] = [[sheet URL] path];
				break;
			}
		}

		[download setDestination:info[@"path"] allowOverwrite:YES];
	} else {
		[download cancel];

		for( NSMutableDictionary *info in _transferStorage ) {
			if( info[@"controller"] == download ) {
				info[@"status"] = @(MVFileTransferStoppedStatus);
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
		[[NSWorkspace sharedWorkspace] openFile:info[@"path"]];

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
		id controller = info[@"controller"];
		if( [controller isKindOfClass:[MVFileTransfer class]] ) {
			MVFileTransfer *transferController = controller;
			NSTimeInterval timeslice = [[transferController startDate] timeIntervalSinceNow] * -1;
			double currentRate = 0.;

			if( ( [transferController status] == MVFileTransferNormalStatus ) && ( [transferController transferred] != [transferController finalSize] ) ) {
				currentRate = ( ( [transferController transferred] - [transferController startOffset] ) / timeslice );
				info[@"rate"] = @(currentRate);
			} else currentRate = [[info valueForKey:@"rate"] doubleValue];

			info[@"status"] = @([transferController status]);

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
			totalSizeDown += [info[@"size"] unsignedLongValue];
			totalTransferredDown += [info[@"transferred"] unsignedLongValue];
			downRate += [info[@"rate"] doubleValue];
			downCount++;
		}
	}

	totalTransferred = totalTransferredDown + totalTransferredUp;
	totalSize = totalSizeDown + totalSizeUp;
	if( upCount && downCount ) {
		upRate = upRate / (float) upCount;
		if( ! totalTransferredUp || ! totalSizeUp ) {
			str = NSLocalizedString( @"nothing uploaded yet", "status of pending upload file transfer" );
		} else if( totalSizeUp != totalTransferredUp ) {
			str = [NSString stringWithFormat:NSLocalizedString( @"%@ of %@ uploaded, at %@ per second", "status of current upload file transfer" ), MVPrettyFileSize( totalTransferredUp ), MVPrettyFileSize( totalSizeUp ), MVPrettyFileSize( upRate )];
		} else if( totalTransferredUp >= totalSizeUp ) {
			str = [NSString stringWithFormat:NSLocalizedString( @"total of %@ uploaded, at %@ per second", "results final upload file transfer" ), MVPrettyFileSize( totalSizeUp ), MVPrettyFileSize( upRate )];
		}
		str = [str stringByAppendingString:@"\n"];
		downRate = downRate / (float) downCount;
		if( ! totalTransferredDown || ! totalSizeDown ) {
			str = [str stringByAppendingString:NSLocalizedString( @"nothing downloaded yet", "status of pending download file transfer" )];
		} else if( totalSizeDown != totalTransferredDown ) {
			str = [str stringByAppendingFormat:NSLocalizedString( @"%@ of %@ downloaded, at %@ per second", "status of current download file transfer" ), MVPrettyFileSize( totalTransferredDown ), MVPrettyFileSize( totalSizeDown ), MVPrettyFileSize( downRate )];
		} else if( totalTransferredDown >= totalSizeDown ) {
			str = [str stringByAppendingFormat:NSLocalizedString( @"total of %@ downloaded, at %@ per second", "results final download file transfer" ), MVPrettyFileSize( totalSizeDown ), MVPrettyFileSize( downRate )];
		}
	} else if( upCount || downCount ) {
		avgRate = ( upRate + downRate ) / ( (float) upCount + (float) downCount );
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

			if( [info[@"controller"] isKindOfClass:[MVFileTransfer class]] )
				startDate = [info[@"controller"] startDate];
			else startDate = info[@"started"];

			if( startDate && [info[@"status"] unsignedIntValue] == MVFileTransferNormalStatus ) {
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
	NSMutableDictionary *info = _transferStorage[index];

	if( [info[@"controller"] isKindOfClass:[MVFileTransfer class]] ) {
		MVFileTransfer *transfer = info[@"controller"];
		info[@"status"] = @([transfer status]);
		info[@"user"] = [transfer user];
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
