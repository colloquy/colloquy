// Created for Colloquy by Thomas Deniau on 04/05/05.
// Thanks to the Adium project for the interface inspiration.

#import "JVChatTranscriptBrowserPanel.h"
#import "JVChatTranscript.h"
#import "JVStyle.h"
#import "JVStyleView.h"
#import "MVApplicationController.h"

id sharedBrowser = nil;
NSString *criteria[4] = { @"server", @"target", @"session", nil };

@implementation JVChatTranscriptBrowserPanel
+ (JVChatTranscriptBrowserPanel *) sharedBrowser {
	if( sharedBrowser ) return sharedBrowser;
	else return [[self alloc] init];
}

#pragma mark -

- (NSString *) logsPath {
	return [[[NSUserDefaults standardUserDefaults] stringForKey:@"JVChatTranscriptFolder"] stringByStandardizingPath];
}

- (NSString *) indexPath {
	return [[@"~/Library/Application Support/Colloquy" stringByExpandingTildeInPath] stringByAppendingPathComponent:@"Transcript Search Index"];
}

- (NSString *) dirtyPath {
	return [[@"~/Library/Application Support/Colloquy" stringByExpandingTildeInPath] stringByAppendingPathComponent:@"Dirty Transcripts"];
}

- (void) updateStatus {
	NSUInteger c = 0;
	@synchronized( _dirtyLogs ) {
		c = [_dirtyLogs count];
	}

	if( c > 1 ) [statusText setStringValue:[NSString stringWithFormat:NSLocalizedString( @"%d logs still have to be indexed", "number of transcripts indexing remains message" ),c]];
	else if( c == 1 ) [statusText setStringValue:NSLocalizedString( @"One log still has to be indexed", "one  indexing remains message" )];
	else [statusText setStringValue:NSLocalizedString( @"Indexing is complete", "transcripts indexing finished message" )];
}

#pragma mark -

- (id) init {
	if( ! sharedBrowser && ( self = [super init] ) ) {
		NSMutableDictionary *tempDictionary = [NSMutableDictionary dictionary];
		NSInteger org = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatTranscriptFolderOrganization"];

		NSInteger serverIndex = -1;
		NSInteger targetIndex = -1;
		NSInteger sessionIndex = 2;
		NSRegularExpression *regex = nil;
		switch( org ) {
		case 0: // all in the same folder, w/server
			targetIndex = 0;
			serverIndex = 1;
			regex = [NSRegularExpression cachedRegularExpressionWithPattern:@"(?P<target>.*) \\((?P<server>.*)\\) ?(?P<session>.*)\\.colloquyTranscript" options:0 error:nil];
			break;
		case 1: // a folder for each server
			targetIndex = 1;
			serverIndex = 0;
			regex = [NSRegularExpression cachedRegularExpressionWithPattern:@"(?P<server>.*)/(?P<target>.*) ?(?P<session>.*)\\.colloquyTranscript" options:0 error:nil];
			break;
		case 2: // a folder for each (server,target)
			targetIndex = 0;
			serverIndex = 1;
			regex = [NSRegularExpression cachedRegularExpressionWithPattern:@"(?P<target>.*) \\((?P<server>.*)\\)/(.* )?(?P<session>.*)\\.colloquyTranscript" options:0 error:nil];
			break;
		case 3: // a folder for each server, then for each target
			targetIndex = 1;
			serverIndex = 0;
			regex = [NSRegularExpression cachedRegularExpressionWithPattern:@"(?P<server>.*)/(?P<target>.*)/(.* )?(?P<session>.*)\\.colloquyTranscript" options:0 error:nil];
			break;
		}

		if( [[NSFileManager defaultManager] fileExistsAtPath:[self dirtyPath]] )
			_dirtyLogs = [[NSKeyedUnarchiver unarchiveObjectWithFile:[self dirtyPath]] retain];
		else _dirtyLogs = [[NSMutableSet alloc] init];

		if( [[NSFileManager defaultManager] fileExistsAtPath:[self indexPath]] ) {
			_shouldIndex = NO;
			_logsIndex = SKIndexOpenWithURL( (CFURLRef) [NSURL fileURLWithPath:[self indexPath]], NULL, YES );
		} else {
			_shouldIndex = YES;
			_logsIndex = SKIndexCreateWithURL( (CFURLRef) [NSURL fileURLWithPath:[self indexPath]], NULL, kSKIndexInverted, NULL );
		}

		CFArrayRef indexes = CFArrayCreate( kCFAllocatorDefault, (void *) &_logsIndex, 1, &kCFTypeArrayCallBacks );
		_searchGroup = SKSearchGroupCreate( indexes );
		CFRelease( indexes );

		NSDirectoryEnumerator *logsEnum = [[NSFileManager defaultManager] enumeratorAtPath:[self logsPath]];
		NSString *logPath = nil;

		while( ( logPath = [logsEnum nextObject] ) ) {
			if( [[logPath pathExtension] isEqualToString:@"colloquyTranscript"] ) {
				// analyze the path
				NSTextCheckingResult *match = [regex matchesInString:logPath options:NSMatchingReportCompletion range:NSMakeRange( 0, logPath.length )];

				NSString *server = [logPath substringWithRange:[match rangeAtIndex:serverIndex]];
				NSString *target = [logPath substringWithRange:[match rangeAtIndex:targetIndex]];
				NSString *session = [logPath substringWithRange:[match rangeAtIndex:sessionIndex]];
				NSString *path = [[self logsPath] stringByAppendingPathComponent:logPath];

				FILE *logsFile = fopen( [path fileSystemRepresentation], "r" );
				if( logsFile ) {
					int fd = fileno( logsFile );

					char buffer[1024];
					ssize_t size = 0;

					if( ( size = fgetxattr( fd, "server", buffer, 1023, 0, 0 ) ) > 0 ) {
						buffer[size] = 0;
						server = [NSString stringWithUTF8String:buffer];
					}

					if( ( size = fgetxattr( fd, "target", buffer, 1023, 0, 0 ) ) > 0 ) {
						buffer[size] = 0;
						target = [NSString stringWithUTF8String:buffer];
					}

					if( ( size = fgetxattr( fd, "dateBegan", buffer, 1023, 0, 0 ) ) > 0 ) {
						buffer[size] = 0;
						session = [NSString stringWithUTF8String:buffer];
					}

					fclose( logsFile );
				}

				NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:server, @"server", target, @"target", session, @"session", path, @"path", nil];
				[tempDictionary setObject:d forKey:path];
				if( _shouldIndex ) [_dirtyLogs addObject:path];
			}
		}

		_shouldIndex = NO;
		[regex release];

		_transcripts = [tempDictionary copyWithZone:[self zone]];
		_filteredTranscripts = [[_transcripts allValues] copyWithZone:[self zone]];
		_selectedTag = 1;
		_nibLoaded = NO;

		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( beginIndexing: ) name:JVMachineBecameIdleNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( stopIndexing: ) name:JVMachineStoppedIdlingNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( markDirty: ) name:JVChatTranscriptUpdatedNotification object:nil];

		if( [_dirtyLogs count] ) [self performSelector:@selector( beginIndexing: ) withObject:nil afterDelay:0.];

		sharedBrowser = self;
	} else [super dealloc];

	return sharedBrowser;
}

- (void) dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[[NSNotificationCenter chatCenter] removeObserver:self];

	_shouldIndex = NO;
	[NSKeyedArchiver archiveRootObject:_dirtyLogs toFile:[self dirtyPath]];

	CFRelease( _logsIndex ); // was SKIndexClose, functionally equivalent
	CFRelease( _searchGroup );

	[tableView setDataSource:nil];
	[tableView setDelegate:nil];

	[_dirtyLogs release];
	[_filteredTranscripts release];
	[_transcripts release];

	_dirtyLogs = nil;
	_filteredTranscripts = nil;
	_transcripts = nil;

	[super dealloc];
}

#pragma mark -

- (IBAction) showBrowser:(id) sender {
	if( ! _nibLoaded ) _nibLoaded = [[NSBundle mainBundle] loadNibNamed:@"JVChatTranscriptBrowserPanel" owner:self topLevelObjects:NULL];
	[window makeKeyAndOrderFront:self];
}

- (NSView *) view {
	if( ! _nibLoaded ) _nibLoaded = [[NSBundle mainBundle] loadNibNamed:@"JVChatTranscriptBrowserPanel" owner:self topLevelObjects:NULL];
	return [window contentView];
}

- (void) awakeFromNib {
	[super awakeFromNib];
	[self updateStatus];
}

#pragma mark -

- (int) numberOfRowsInTableView:(NSTableView *) tableview {
	return [_filteredTranscripts count];
}

- (id) tableView:(NSTableView *) tableview objectValueForTableColumn:(NSTableColumn *) column row:(int) row {
	return [[_filteredTranscripts objectAtIndex:row] objectForKey:[column identifier]];
}

- (void) tableView:(NSTableView *) tableview sortDescriptorsDidChange:(NSArray *) oldDescriptors {
	NSArray *sorted = [_filteredTranscripts sortedArrayUsingDescriptors:[tableView sortDescriptors]];

	NSInteger selectedRow = [tableView selectedRow];
	NSDictionary *selected = nil;
	if( selectedRow != -1 ) selected = [_filteredTranscripts objectAtIndex:selectedRow];

	[_filteredTranscripts release];
	_filteredTranscripts = [sorted retain];

	[tableView reloadData];
	if( selected ) [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[sorted indexOfObject:selected]] byExtendingSelection:NO];
}

#pragma mark -

- (IBAction) search:(id) sender {
	if( [[searchField stringValue] length] ) {
		if( criteria[_selectedTag] ) {
			NSMutableArray *filtered = [[NSMutableArray alloc] initWithCapacity:[_transcripts count]];
			for( NSDictionary *d in _transcripts ) {
				if( [[d objectForKey:criteria[_selectedTag]] rangeOfString:[searchField stringValue]].location != NSNotFound ) {
					[filtered addObject:d];
				}
			}

			[_filteredTranscripts release];
			_filteredTranscripts = [filtered retain];
		} else {
			NSMutableArray *tempArray = [[NSMutableArray alloc] init];

			SKIndexFlush( _logsIndex );
			SKSearchResultsRef results = SKSearchResultsCreateWithQuery( _searchGroup, (CFStringRef) [searchField stringValue], kSKSearchPrefixRanked, [_transcripts count], NULL, NULL );

			CFIndex resultCount = SKSearchResultsGetCount( results );

			SKDocumentRef *outDocumentsArray = malloc( sizeof( SKDocumentRef ) * resultCount );
			float *outScoresArray = malloc( sizeof( float ) * resultCount );
			CFRange resultRange = CFRangeMake( 0, resultCount );

			SKSearchResultsGetInfoInRange( results, resultRange, outDocumentsArray, NULL, outScoresArray );

			NSUInteger i = 0;
			for( i = 0; i < resultCount; i++ ) {
				CFURLRef url = SKDocumentCopyURL( outDocumentsArray[i] );
				NSString *path = [(NSURL*)url path];
				CFRelease( url );

				NSMutableDictionary *theLog = [[[_transcripts objectForKey:path] mutableCopy] autorelease];
				[theLog setObject:[NSNumber numberWithFloat:outScoresArray[i]] forKey:@"relevancy"];
				[theLog setObject:path forKey:@"path"];

				[tempArray addObject:theLog];
			}

			[_filteredTranscripts release];
			_filteredTranscripts = tempArray;
		}
	} else {
		[_filteredTranscripts release];
		_filteredTranscripts = [[_transcripts allValues] copy];
	}

	[tableView reloadData];
}

- (IBAction) changeCriterion:(id) sender {
	[[searchField cell] setPlaceholderString:[sender title]];
	_selectedTag = [sender tag];

	NSMenu *template = [[[searchField cell] searchMenuTemplate] copy];
	for( NSUInteger i = 0; i < 4; i++ )
		[[template itemWithTag:i] setState:( i == _selectedTag ? NSOnState : NSOffState )];
	[[searchField cell] setSearchMenuTemplate:template];
	[template release];

	[self search:self];
}

#pragma mark -

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	NSInteger selectedRow = [tableView selectedRow];
	if( selectedRow != -1 ) {
		[_transcript release];
		_transcript = [[JVChatTranscript alloc] initWithContentsOfFile:[[_filteredTranscripts objectAtIndex:selectedRow] objectForKey:@"path"]];
		[display setTranscript:_transcript];
		[self setSearchQuery:[searchField stringValue]];
		[display reloadCurrentStyle];
	}
}

#pragma mark -

- (void) beginIndexing:(NSNotification *) notification {
	_shouldIndex = YES;
	[NSThread detachNewThreadSelector:@selector( indexingThread ) toTarget:self withObject:nil];
}

- (void) indexingThread {
	@autoreleasepool {
		NSString *path = nil;
		
		[NSThread setThreadPriority:0.25];
		
		while( _shouldIndex ) {
			@synchronized( _dirtyLogs ) {
				path = [[_dirtyLogs anyObject] retain];
				if( path ) [_dirtyLogs removeObject:path];
			}
			
			if( ! path ) break;
			
			SKDocumentRef document = SKDocumentCreateWithURL( (CFURLRef) [NSURL fileURLWithPath:path] );
			NSString *toIndex = [[NSString alloc] initWithContentsOfFile:path]; // FIXME strip xml (w/o NSXMLDocument...) ?
			SKIndexAddDocumentWithText( _logsIndex, document, (CFStringRef) toIndex, YES );
			CFRelease( document );
			
			[toIndex release];
			[path release];
			
			[self performSelectorOnMainThread:@selector( updateStatus ) withObject:nil waitUntilDone:NO];
		}
		
		[self performSelectorOnMainThread:@selector( syncDirtyLogsList ) withObject:nil waitUntilDone:NO];
		
		SKIndexFlush( _logsIndex );
		
	}
}

- (void) stopIndexing:(NSNotification *) notification {
	_shouldIndex = NO;
}

#pragma mark -

- (void) markDirty:(JVChatTranscript *) transcript {
	NSString *path = nil;
	if( [transcript isKindOfClass:[NSNotification class]] )
		path = [(JVChatTranscript *)[(NSNotification *)transcript object] filePath];
	else if( [transcript isKindOfClass:[JVChatTranscript class]] )
		path = [transcript filePath];
	else return;

	@synchronized( _dirtyLogs ) {
		[_dirtyLogs addObject:path];
		[NSKeyedArchiver archiveRootObject:_dirtyLogs toFile:[self dirtyPath]];
	}

	[self updateStatus];
}

- (void) syncDirtyLogsList {
	@synchronized( _dirtyLogs ) {
		if( [_dirtyLogs count] ) [NSKeyedArchiver archiveRootObject:_dirtyLogs toFile:[self dirtyPath]];
		else [[NSFileManager defaultManager] removeFileAtPath:[self dirtyPath] handler:nil];
	}
}
@end
