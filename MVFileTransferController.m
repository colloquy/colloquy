#import <Cocoa/Cocoa.h>
#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVFileTransfer.h>
#import <WebKit/WebDownload.h>

#import "MVFileTransferController.h"
#import "MVBuddyListController.h"
#import "MVApplicationController.h"
#import "JVBuddy.h"
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
- (void) _incomingFileSheetDidEnd:(NSWindow *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo;
- (void) _incomingFileSavePanelDidEnd:(NSSavePanel *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo;
- (void) _downloadFileSavePanelDidEnd:(NSSavePanel *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo;
- (NSMutableDictionary *) _infoForTransferAtIndex:(unsigned int) index;
@end

#pragma mark -

@implementation MVFileTransferController
+ (NSString *) userPreferredDownloadFolder {
	OSStatus err = noErr;
	ICInstance inst = NULL;
	ICFileSpec folder;
	unsigned long length = kICFileSpecHeaderSize;
	FSRef ref;
	unsigned char path[1024];

	memset( path, 0, 1024 );

	if( ( err = ICStart( &inst, 'coRC' ) ) != noErr )
		goto finish;

	ICGetPref( inst, kICDownloadFolder, NULL, &folder, &length );
	ICStop( inst );

	if( ( err = FSpMakeFSRef( &folder.fss, &ref ) ) != noErr )
		goto finish;

	if( ( err = FSRefMakePath( &ref, path, 1024 ) ) != noErr )
		goto finish;

finish:

	if( ! strlen( path ) )
		return [@"~/Desktop" stringByExpandingTildeInPath];

	return [NSString stringWithUTF8String:path];
}

+ (void) setUserPreferredDownloadFolder:(NSString *) path {
	OSStatus err = noErr;
	ICInstance inst = NULL;
	ICFileSpec *dir = NULL;
	FSRef ref;
	AliasHandle alias;
	unsigned long length = 0;

	if( ( err = FSPathMakeRef( [path UTF8String], &ref, NULL ) ) != noErr )
		return;

	if( ( err = FSNewAliasMinimal( &ref, &alias ) ) != noErr )
 		return;

	length = ( kICFileSpecHeaderSize + GetHandleSize( (Handle) alias ) );
	dir = malloc( length );
	memset( dir, 0, length );

	if( ( err = FSGetCatalogInfo( &ref, kFSCatInfoNone, NULL, NULL, &dir -> fss, NULL ) ) != noErr )
		return;

	memcpy( &dir -> alias, *alias, length - kICFileSpecHeaderSize );

	if( ( err = ICStart( &inst, 'coRC' ) ) != noErr )
		return;

	ICSetPref( inst, kICDownloadFolder, NULL, dir, length );
	ICStop( inst );

	free( dir );
	DisposeHandle( (Handle) alias );
}

#pragma mark -

+ (MVFileTransferController *) defaultManager {
	extern MVFileTransferController *sharedInstance;
	if( ! sharedInstance && [MVApplicationController isTerminating] ) return nil;
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] initWithWindowNibName:nil] ) );
}

#pragma mark -

- (id) initWithWindowNibName:(NSString *) windowNibName {
	if( ( self = [super initWithWindowNibName:@"MVFileTransfer"] ) ) {
		_transferStorage = [[NSMutableArray array] retain];
		_calculationItems = [[NSMutableArray array] retain];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _incomingFile: ) name:MVDownloadFileTransferOfferNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _fileTransferStarted: ) name:MVFileTransferStartedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _fileTransferFinished: ) name:MVFileTransferFinishedNotification object:nil];

		_safeFileExtentions = [[NSSet setWithObjects:@"jpg",@"jpeg",@"gif",@"png",@"tif",@"tiff",@"psd",@"pdf",@"txt",@"rtf",@"html",@"htm",@"swf",@"mp3",@"wma",@"wmv",@"ogg",@"ogm",@"mov",@"mpg",@"mpeg",@"m1v",@"m2v",@"mp4",@"avi",@"vob",@"avi",@"asx",@"asf",@"pls",@"m3u",@"rmp",@"aif",@"aiff",@"aifc",@"wav",@"wave",@"m4a",@"m4p",@"m4b",@"dmg",@"udif",@"ndif",@"dart",@"sparseimage",@"cdr",@"dvdr",@"iso",@"img",@"toast",@"rar",@"sit",@"sitx",@"bin",@"hqx",@"zip",@"gz",@"tgz",@"tar",@"bz",@"bz2",@"tbz",@"z",@"taz",@"uu",@"uue",@"colloquytranscript",@"torrent",nil] retain];
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

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if( self == sharedInstance ) sharedInstance = nil;
	
	[_transferStorage release];
	[_safeFileExtentions release];
	[_calculationItems release];
	[_updateTimer release];

	_transferStorage = nil;
	_safeFileExtentions = nil;
	_calculationItems = nil;
	_updateTimer = nil;

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
	WebDownload *download = [[[WebDownload alloc] initWithRequest:[NSURLRequest requestWithURL:url] delegate:self] autorelease];

	if( ! download ) {
		NSBeginAlertSheet( @"Invalid URL", nil, nil, nil, [self window], nil, nil, nil, nil, @"The download URL is either invalid or unsupported." );
		return;
	}

	[self showTransferManager:nil];
	
	if( path ) [download setDestination:path allowOverwrite:NO];

	NSMutableDictionary *info = [NSMutableDictionary dictionary];
	[info setObject:[NSNumber numberWithUnsignedLong:0] forKey:@"transfered"];
	[info setObject:[NSNumber numberWithUnsignedInt:0] forKey:@"rate"];
	[info setObject:[NSNumber numberWithUnsignedLong:0] forKey:@"size"];
	[info setObject:download forKey:@"controller"];
	[info setObject:url forKey:@"url"];

	if( path ) [info setObject:path forKey:@"path"];
	else [info setObject:[[url path] lastPathComponent] forKey:@"path"];

	[_transferStorage addObject:info];
	[currentFiles reloadData];
	[self showTransferManager:nil];
}

- (void) addFileTransfer:(MVFileTransfer *) transfer {
	NSEnumerator *enumerator = nil;
	NSMutableDictionary *info = nil;
	NSParameterAssert( transfer != nil );

	enumerator = [_transferStorage objectEnumerator];
	while( ( info = [enumerator nextObject] ) )
		if( [[info objectForKey:@"transfer"] isEqualTo:transfer] )
			return;

	info = [NSMutableDictionary dictionary];
	[info setObject:[NSNumber numberWithUnsignedInt:0] forKey:@"rate"];
	[info setObject:[NSNumber numberWithUnsignedInt:[transfer status]] forKey:@"status"];
	[info setObject:[NSNumber numberWithUnsignedLongLong:[transfer finalSize]] forKey:@"size"];
	if( [transfer isDownload] ) [info setObject:[(MVDownloadFileTransfer *)transfer destination] forKey:@"path"];
	[info setObject:transfer forKey:@"controller"];

	[_transferStorage addObject:info];
	[currentFiles reloadData];
	[self showTransferManager:nil];
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
	unsigned i = 0;
	NSDictionary *info = nil;
	if( [currentFiles selectedRow] == -1 ) {
		for( i = 0; i < [_transferStorage count]; ) {
			info = [self _infoForTransferAtIndex:i];
			unsigned int status = [[info objectForKey:@"status"] unsignedIntValue];
			if( status == MVFileTransferDoneStatus || status == MVFileTransferErrorStatus || status == MVFileTransferStoppedStatus ) {
				[_calculationItems removeObject:info];
				[_transferStorage removeObject:info];
				[currentFiles reloadData];
			} else i++;
		}
	} else if( [currentFiles numberOfSelectedRows] == 1 ) {
		info = [self _infoForTransferAtIndex:[currentFiles selectedRow]];
		unsigned int status = [[info objectForKey:@"status"] unsignedIntValue];
		if( status == MVFileTransferDoneStatus || status == MVFileTransferErrorStatus || status == MVFileTransferStoppedStatus ) {
			[_calculationItems removeObject:info];
			[_transferStorage removeObject:info];
			[currentFiles reloadData];
		}
	}

	[self _updateProgress:nil];
}

- (IBAction) revealSelectedFile:(id) sender {
	NSDictionary *info = nil;
	if( [currentFiles numberOfSelectedRows] == 1 ) {
		info = [self _infoForTransferAtIndex:[currentFiles selectedRow]];
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
		[array addObject:[[self _infoForTransferAtIndex:i] objectForKey:@"path"]];
		[string appendString:[[[self _infoForTransferAtIndex:i] objectForKey:@"path"] lastPathComponent]];
		if( ! [[[enumerator allObjects] lastObject] isEqual:row] ) [string appendString:@"\n"];
	}
	[[NSPasteboard generalPasteboard] setPropertyList:array forType:NSFilenamesPboardType];
	[[NSPasteboard generalPasteboard] setString:string forType:NSStringPboardType];
}
@end

#pragma mark -

@implementation MVFileTransferController (MVFileTransferControllerDelegate)
#pragma mark Table View Support
- (int) numberOfRowsInTableView:(NSTableView *) view {
	return [_transferStorage count];
}

- (id) tableView:(NSTableView *) view objectValueForTableColumn:(NSTableColumn *) column row:(int) row {
	if( [[column identifier] isEqual:@"file"] ) {
		NSString *path = [[self _infoForTransferAtIndex:row] objectForKey:@"path"];
		NSImage *fileIcon = [[NSWorkspace sharedWorkspace] iconForFileType:[path pathExtension]];
		[fileIcon setScalesWhenResized:YES];
		[fileIcon setSize:NSMakeSize( 16., 16. )];
		return fileIcon;
	} else if( [[column identifier] isEqual:@"size"] ) {
		unsigned long long size = [[[self _infoForTransferAtIndex:row] objectForKey:@"size"] unsignedLongLongValue];
		NSLog( @"size %d", size );
		return ( size ? MVPrettyFileSize( size ) : @"--" );
	} else if( [[column identifier] isEqual:@"user"] ) {
		NSString *ret = [[self _infoForTransferAtIndex:row] objectForKey:@"user"];
		return ( ret ? ret : NSLocalizedString( @"n/a", "not applicable identifier" ) );
	}
	return nil;
}

- (void) tableView:(NSTableView *) view willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) column row:(int) row {
	if( [[column identifier] isEqual:@"file"] ) {
		NSString *path = [[self _infoForTransferAtIndex:row] objectForKey:@"path"];
		[cell setMainText:[[NSFileManager defaultManager] displayNameAtPath:path]];
	} else if( [[column identifier] isEqual:@"status"] ) {
		id controller = [[self _infoForTransferAtIndex:row] objectForKey:@"controller"];
		MVFileTransferStatus status = (MVFileTransferStatus) [[[self _infoForTransferAtIndex:row] objectForKey:@"status"] unsignedIntValue];
		NSString *imageName = @"pending";
		if( status == MVFileTransferErrorStatus ) imageName = @"error";
		else if( status == MVFileTransferStoppedStatus ) imageName = @"stopped";
		else if( status == MVFileTransferDoneStatus ) imageName = @"done";
		else if( [controller isKindOfClass:[MVUploadFileTransfer class]] ) imageName = @"upload";
		else if( [controller isKindOfClass:[MVDownloadFileTransfer class]] || [controller isKindOfClass:[WebDownload class]] ) imageName = @"download";
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

	enumerator = [currentFiles selectedRowEnumerator];
	[_calculationItems removeAllObjects];
	while( ( item = [enumerator nextObject] ) )
		[_calculationItems addObject:[self _infoForTransferAtIndex:[item unsignedIntValue]]];
}

- (BOOL) tableView:(NSTableView *) view writeRows:(NSArray *) rows toPasteboard:(NSPasteboard *) board {
	NSEnumerator *enumerator = [rows objectEnumerator];
	NSMutableArray *array = [NSMutableArray array];
	id row = nil;

	[board declareTypes:[NSArray arrayWithObjects:NSFilenamesPboardType,nil] owner:self];

	while( ( row = [enumerator nextObject] ) ) {
		NSString *path = [[self _infoForTransferAtIndex:[row unsignedIntValue]] objectForKey:@"path"];
		if( path ) [array addObject:path];
	}

	[board setPropertyList:array forType:NSFilenamesPboardType];
	return YES;
}

#pragma mark -
#pragma mark Toolbar Support

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
#pragma mark Save Panel Trickery

- (NSString *) panel:(id) sender userEnteredFilename:(NSString *) filename confirmed:(BOOL) confirmed {
	return ( confirmed ? [filename stringByAppendingString:@".colloquyFake"] : filename );
}

#pragma mark -
#pragma mark URL Web Download Support

- (void) download:(NSURLDownload *) download decideDestinationWithSuggestedFilename:(NSString *) filename {
	if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVAskForTransferSaveLocation"] ) {
		NSString *path = [[[self class] userPreferredDownloadFolder] stringByAppendingPathComponent:filename];
		NSEnumerator *enumerator = nil;
		NSMutableDictionary *info = nil;

		enumerator = [_transferStorage objectEnumerator];
		while( ( info = [enumerator nextObject] ) ) {
			if( [info objectForKey:@"controller"] == download ) {
				[info setObject:path forKey:@"path"];
				break;
			}
		}

		[self _downloadFileSavePanelDidEnd:nil returnCode:NSOKButton contextInfo:(void *)[download retain]];
	} else {
		NSSavePanel *savePanel = [[NSSavePanel savePanel] retain];
		[savePanel beginSheetForDirectory:[[self class] userPreferredDownloadFolder] file:filename modalForWindow:nil modalDelegate:self didEndSelector:@selector( _downloadFileSavePanelDidEnd:returnCode:contextInfo: ) contextInfo:(void *)[download retain]];
	}
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
			unsigned long long transfered = [[info objectForKey:@"transfered"] unsignedIntValue] + length;

			[info setObject:[NSNumber numberWithUnsignedInt:MVFileTransferNormalStatus] forKey:@"status"];
			[info setObject:[NSNumber numberWithUnsignedLong:transfered] forKey:@"transfered"];

			if( transfered != [[info objectForKey:@"size"] unsignedLongLongValue] )
				[info setObject:[NSNumber numberWithDouble:( transfered / timeslice )] forKey:@"rate"];

			if( ! [info objectForKey:@"started"] ) [info setObject:[NSDate date] forKey:@"started"];

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
	
	enumerator = [[[_transferStorage copy] autorelease] objectEnumerator];
	while( ( info = [enumerator nextObject] ) ) {
		if( [info objectForKey:@"controller"] == download ) {
			[info setObject:[NSNumber numberWithUnsignedInt:MVFileTransferDoneStatus] forKey:@"status"];

			[[NSWorkspace sharedWorkspace] noteFileSystemChanged:[info objectForKey:@"path"]];

			if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVOpenSafeFiles"] && [_safeFileExtentions containsObject:[[[info objectForKey:@"path"] pathExtension] lowercaseString]] )
				[[NSWorkspace sharedWorkspace] openFile:[info objectForKey:@"path"] withApplication:nil andDeactivate:NO];

			if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVRemoveTransferedItems"] == 2 ) {
				[_calculationItems removeObject:info];
				[_transferStorage removeObject:info];
				[currentFiles reloadData];
			}

			break;
		}
	}
}

- (void) download:(NSURLDownload *) download didFailWithError:(NSError *) error {
	NSEnumerator *enumerator = nil;
	NSMutableDictionary *info = nil;

	enumerator = [_transferStorage objectEnumerator];
	while( ( info = [enumerator nextObject] ) ) {
		if( [info objectForKey:@"controller"] == download ) {
			[info setObject:[NSNumber numberWithUnsignedInt:MVFileTransferErrorStatus] forKey:@"status"];
			break;
		}
	}
}
@end

#pragma mark -

@implementation MVFileTransferController (MVFileTransferControllerPrivate)
#pragma mark ChatCore File Transfer Support
- (void) _fileTransferStarted:(NSNotification *) notification {
	MVDownloadFileTransfer *transfer = [notification object];
	NSEnumerator *enumerator = nil;
	NSMutableDictionary *info = nil;

	enumerator = [[[_transferStorage copy] autorelease] objectEnumerator];
	while( ( info = [enumerator nextObject] ) ) {
		if( [[info objectForKey:@"controller"] isEqualTo:transfer] ) {
			[info setObject:[transfer startDate] forKey:@"startDate"];
			break;
		}
	}

	[currentFiles reloadData];
}

- (void) _fileTransferFinished:(NSNotification *) notification {
	MVDownloadFileTransfer *transfer = [notification object];
	NSEnumerator *enumerator = nil;
	NSMutableDictionary *info = nil;

	enumerator = [[[_transferStorage copy] autorelease] objectEnumerator];
	while( ( info = [enumerator nextObject] ) ) {
		if( [[info objectForKey:@"controller"] isEqualTo:transfer] ) {
			NSString *path = [transfer destination];

			[[NSWorkspace sharedWorkspace] noteFileSystemChanged:path];

			if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVOpenSafeFiles"] && [_safeFileExtentions containsObject:[[path pathExtension] lowercaseString]] )
				[[NSWorkspace sharedWorkspace] openFile:path withApplication:nil andDeactivate:NO];

			if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVRemoveTransferedItems"] == 2 ) {
				[_calculationItems removeObject:info];
				[_transferStorage removeObject:info];
				[currentFiles reloadData];
			}

			break;
		}
	}

	[currentFiles reloadData];
}

- (void) _incomingFile:(NSNotification *) notification {
	MVDownloadFileTransfer *transfer = [notification object];

	if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVAutoAcceptFilesFrom"] == 3 ) {
		[self _incomingFileSheetDidEnd:nil returnCode:NSOKButton contextInfo:(void *)[transfer retain]];
	} else if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVAutoAcceptFilesFrom"] == 2 ) {
		JVBuddy *buddy = [[MVBuddyListController sharedBuddyList] buddyForNickname:[transfer fromNickname] onServer:[(MVChatConnection *)[transfer connection] server]];
		if( buddy ) [self _incomingFileSheetDidEnd:nil returnCode:NSOKButton contextInfo:(void *)[transfer retain]];
		else NSBeginInformationalAlertSheet( NSLocalizedString( @"Incoming File Transfer", "new file transfer dialog title" ), NSLocalizedString( @"Accept", "accept button name" ), NSLocalizedString( @"Refuse", "refuse button name" ), nil, nil, self, @selector( _incomingFileSheetDidEnd:returnCode:contextInfo: ), NULL, (void *)[transfer retain], NSLocalizedString( @"A file named \"%@\" is being sent to you from %@. This file is %@ in size.", "new file transfer dialog message" ), [transfer originalFileName], [transfer fromNickname], MVPrettyFileSize( [transfer finalSize] ) );
	} else if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVAutoAcceptFilesFrom"] == 1 ) {
		NSBeginInformationalAlertSheet( NSLocalizedString( @"Incoming File Transfer", "new file transfer dialog title" ), NSLocalizedString( @"Accept", "accept button name" ), NSLocalizedString( @"Refuse", "refuse button name" ), nil, nil, self, @selector( _incomingFileSheetDidEnd:returnCode:contextInfo: ), NULL, (void *)[transfer retain], NSLocalizedString( @"A file named \"%@\" is being sent to you from %@. This file is %@ in size.", "new file transfer dialog message" ), [transfer originalFileName], [transfer fromNickname], MVPrettyFileSize( [transfer finalSize] ) );
	}
}

- (void) _incomingFileSheetDidEnd:(NSWindow *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	MVDownloadFileTransfer *transfer = [(MVDownloadFileTransfer *)contextInfo autorelease];

	if( returnCode == NSOKButton ) {
		if( ! [[NSUserDefaults standardUserDefaults] boolForKey:@"JVAskForTransferSaveLocation"] ) {
			NSString *path = [[[self class] userPreferredDownloadFolder] stringByAppendingPathComponent:[transfer originalFileName]];
			[sheet close];
			[transfer setDestination:path renameIfFileExists:NO];
			[self _incomingFileSavePanelDidEnd:nil returnCode:NSOKButton contextInfo:(void *)[transfer retain]];
		} else {
			NSSavePanel *savePanel = [[NSSavePanel savePanel] retain];
			[sheet close];
			[savePanel setDelegate:self];
			[savePanel beginSheetForDirectory:[[self class] userPreferredDownloadFolder] file:[transfer originalFileName] modalForWindow:nil modalDelegate:self didEndSelector:@selector( _incomingFileSavePanelDidEnd:returnCode:contextInfo: ) contextInfo:(void *)[transfer retain]];
		}
	} else [transfer reject];
}

- (void) _incomingFileSavePanelDidEnd:(NSSavePanel *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	MVDownloadFileTransfer *transfer = [(MVDownloadFileTransfer *)contextInfo autorelease];
	[sheet autorelease];

	if( returnCode == NSOKButton ) {
		NSString *filename = ( [[sheet filename] hasSuffix:@".colloquyFake"] ? [[sheet filename] stringByDeletingPathExtension] : [sheet filename] );
		if( ! filename ) filename = [transfer destination];
		NSNumber *size = [[[NSFileManager defaultManager] fileAttributesAtPath:filename traverseLink:YES] objectForKey:NSFileSize];
		BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:filename];
		BOOL resumePossible = ( fileExists && [size unsignedLongLongValue] < [transfer finalSize] ? YES : NO );
		int result = NSOKButton;

		if( resumePossible ) result = NSRunAlertPanel( NSLocalizedString( @"Save", "save dialog title" ), NSLocalizedString( @"The file %@ in %@ already exists. Would you like to resume from where a previous transfer stopped or replace it?", "replace or resume transfer save dialog message" ), NSLocalizedString( @"Resume", "resume button name" ), ( sheet ? @"Cancel" : NSLocalizedString( @"Save As...", "save as button name" ) ), NSLocalizedString( @"Replace", "replace button name" ), [[NSFileManager defaultManager] displayNameAtPath:filename], [filename stringByDeletingLastPathComponent] );
		else if( fileExists ) result = NSRunAlertPanel( NSLocalizedString( @"Save", "save dialog title" ), NSLocalizedString( @"The file %@ in %@ already exists and can't be resumed. Replace it?", "replace transfer save dialog message" ), NSLocalizedString( @"Replace", "replace button name" ), ( sheet ? @"Cancel" : NSLocalizedString( @"Save As...", "save as button name" ) ), nil, [[NSFileManager defaultManager] displayNameAtPath:filename], [filename stringByDeletingLastPathComponent] );

		if( result == NSCancelButton ) {
			NSSavePanel *savePanel = [[NSSavePanel savePanel] retain];
			[sheet close];
			[savePanel setDelegate:self];
			[savePanel beginSheetForDirectory:[sheet directory] file:[filename lastPathComponent] modalForWindow:nil modalDelegate:self didEndSelector:@selector( _incomingFileSavePanelDidEnd:returnCode:contextInfo: ) contextInfo:(void *)[transfer retain]];
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

- (void) _downloadFileSavePanelDidEnd:(NSSavePanel *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo {
	WebDownload *download = [(WebDownload *) contextInfo autorelease]; // for the previous retain
	[sheet autorelease];
	if( returnCode == NSOKButton ) {
		NSEnumerator *enumerator = nil;
		NSMutableDictionary *info = nil;

		enumerator = [_transferStorage objectEnumerator];
		while( ( info = [enumerator nextObject] ) ) {
			if( [info objectForKey:@"controller"] == download ) {
				if( sheet ) [info setObject:[sheet filename] forKey:@"path"];
				break;
			}
		}

		[download setDestination:[info objectForKey:@"path"] allowOverwrite:YES];
	} else {
		NSEnumerator *enumerator = nil;
		NSMutableDictionary *info = nil;

		[download cancel];

		enumerator = [_transferStorage objectEnumerator];
		while( ( info = [enumerator nextObject] ) ) {
			if( [info objectForKey:@"controller"] == download ) {
				[info setObject:[NSNumber numberWithUnsignedInt:MVFileTransferStoppedStatus] forKey:@"status"];
				break;
			}
		}
	}
}

- (void) _openFile:(id) sender {
	NSDictionary *info = nil;
	NSEnumerator *enumerator = [currentFiles selectedRowEnumerator];
	id item = nil;

	while( ( item = [enumerator nextObject] ) ) {
		info = [self _infoForTransferAtIndex:[currentFiles selectedRow]];
		[[NSWorkspace sharedWorkspace] openFile:[info objectForKey:@"path"]];
	}
}

- (void) _updateProgress:(id) sender {
	NSString *str = nil;
	NSEnumerator *enumerator = nil;
	NSMutableDictionary *info = nil;
	unsigned long long totalSizeUp = 0, totalTransferedUp = 0, totalTransfered = 0, totalSize = 0;
	unsigned long long totalSizeDown = 0, totalTransferedDown = 0;
	double upRate = 0., downRate = 0., avgRate = 0.;
	unsigned upCount = 0, downCount = 0;

	if( sender && ! [[self window] isVisible] ) return;

	if( [_calculationItems count] ) enumerator = [_calculationItems objectEnumerator];
	else enumerator = [_transferStorage objectEnumerator];
	while( ( info = [enumerator nextObject] ) ) {
		id controller = [info objectForKey:@"controller"];
		if( [controller isKindOfClass:[MVUploadFileTransfer class]] ) {
			totalSizeUp += [controller finalSize];
			totalTransferedUp += [controller transfered];

			NSTimeInterval timeslice = [[controller startDate] timeIntervalSinceNow] * -1;
			if( [controller status] == MVFileTransferNormalStatus && [controller transfered] != [controller finalSize] )
				[info setObject:[NSNumber numberWithDouble:( ( [controller transfered] - [controller startOffset] ) / timeslice )] forKey:@"rate"];

			[info setObject:[NSNumber numberWithUnsignedInt:[controller status]] forKey:@"status"];

			upRate += [[info objectForKey:@"rate"] doubleValue];
			upCount++;
		} else if( [controller isKindOfClass:[MVDownloadFileTransfer class]] ) {
			totalSizeDown += [controller finalSize];
			totalTransferedDown += [controller transfered];

			NSTimeInterval timeslice = [[controller startDate] timeIntervalSinceNow] * -1;
			if( [controller status] == MVFileTransferNormalStatus && [controller transfered] != [controller finalSize] )
				[info setObject:[NSNumber numberWithDouble:( ( [controller transfered] - [controller startOffset] ) / timeslice )] forKey:@"rate"];

			[info setObject:[NSNumber numberWithUnsignedInt:[controller status]] forKey:@"status"];

			downRate += [[info objectForKey:@"rate"] doubleValue];
			downCount++;
		} else if( [controller isKindOfClass:[WebDownload class]] ) {
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
				if( avgRate > 0 ) str = [str stringByAppendingFormat:NSLocalizedString( @"%@ elapsed, %@ remaining", "time that has passed and time that remains on selected transfer" ), MVReadableTime( [startDate timeIntervalSince1970], YES ), MVReadableTime( [[NSDate date] timeIntervalSince1970] + ( ( totalSize - totalTransfered) / avgRate ), NO )];
				else if( startDate ) str = [str stringByAppendingFormat:NSLocalizedString( @"%@ elapsed", "time that has passed on selected transfer" ), MVReadableTime( [startDate timeIntervalSince1970], YES )];
			}
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

- (NSMutableDictionary *) _infoForTransferAtIndex:(unsigned int) index {
	NSMutableDictionary *info = [_transferStorage objectAtIndex:index];

	if( [[info objectForKey:@"controller"] isKindOfClass:[MVFileTransfer class]] ) {
		MVFileTransfer *transfer = [info objectForKey:@"controller"];
		[info setObject:[NSNumber numberWithUnsignedLongLong:[transfer transfered]] forKey:@"transfered"];
		[info setObject:[NSNumber numberWithUnsignedInt:[transfer status]] forKey:@"status"];
		if( [transfer isDownload] ) {
			[info setObject:[(MVDownloadFileTransfer *)transfer fromNickname] forKey:@"user"];
		} else if( [transfer isUpload] ) {
	//		[info setObject:[transfer fromNickname] forKey:@"user"];
		}
	}

	return info;
}
@end