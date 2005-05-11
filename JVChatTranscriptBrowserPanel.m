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
	unsigned int c = 0;
	@synchronized( _dirtyLogs ) {
		c = [_dirtyLogs count];
	}

	if( c > 1 ) [statusText setStringValue:[NSString stringWithFormat:@"%d logs still have to be indexed",c]];
	else if( c == 1 ) [statusText setStringValue:@"One log still has to be indexed"];
	else [statusText setStringValue:@"Indexing is complete"];
}

#pragma mark -

- (id) init {
	if( ! sharedBrowser && ( self = [super init] ) ) {
		NSMutableDictionary *tempDictionary = [NSMutableDictionary dictionary];
		int org = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatTranscriptFolderOrganization"];
		int session = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatTranscriptSessionHandling"];

		AGRegex *regex = nil;
		switch( org ) {
		case 0: // all in the same folder, w/server
			regex = [[AGRegex alloc] initWithPattern:@"(?P<target>.*) \\((?P<server>.*)\\) ?(?P<session>.*)\\.colloquyTranscript"]; 
			break;
		case 1: // a folder for each server
			regex = [[AGRegex alloc] initWithPattern:@"(?P<server>.*)/(?P<target>.*) ?(?P<session>.*)\\.colloquyTranscript"];
			break;
		case 2: // a folder for each (server,target)
			regex = [[AGRegex alloc] initWithPattern:@"(?P<target>.*) \\((?P<server>.*)\\)/(.* )?(?P<session>.*)\\.colloquyTranscript"];
			break;
		case 3: // a folder for each server, then for each target
			regex = [[AGRegex alloc] initWithPattern:@"(?P<server>.*)/(?P<target>.*)/(.* )?(?P<session>.*)\\.colloquyTranscript"];
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
				AGRegexMatch *match = [regex findInString:logPath];

				NSString *server = [match groupNamed:@"server"];
				NSString *target = [match groupNamed:@"target"];
				NSString *session = [match groupNamed:@"session"];
				NSString *path = [[self logsPath] stringByAppendingPathComponent:logPath];

#ifdef NSAppKitVersionNumber10_3
				if( floor( NSAppKitVersionNumber ) > NSAppKitVersionNumber10_3 ) {
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
				}
#endif

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

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( beginIndexing: ) name:JVMachineBecameIdleNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( stopIndexing: ) name:JVMachineStoppedIdlingNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( markDirty: ) name:JVChatTranscriptUpdatedNotification object:nil];

		if( [_dirtyLogs count] ) [self performSelector:@selector( beginIndexing: ) withObject:nil afterDelay:0.];

		sharedBrowser = self;
	} else [super dealloc];

	return sharedBrowser;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	_shouldIndex = NO;
	[NSKeyedArchiver archiveRootObject:_dirtyLogs toFile:[self dirtyPath]];

	SKIndexClose( _logsIndex );
	CFRelease( _searchGroup );

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
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"JVChatTranscriptBrowserPanel" owner:self];
	[window makeKeyAndOrderFront:self];
}

- (NSView *) view {
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"JVChatTranscriptBrowserPanel" owner:self];
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

	int selectedRow = [tableView selectedRow];
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
			NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:[_transcripts count]];
			NSEnumerator *enumerator = [_transcripts objectEnumerator];
			NSDictionary *d = nil;

			while( ( d = [enumerator nextObject] ) ) {
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
			int i = 0;

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

	int i = 0;
	for( i = 0; i < 4; i++ )
		[[[searchField menu] itemWithTag:i] setState:( i == _selectedTag ? NSOnState : NSOffState )];

	[self search:self];
}

#pragma mark -

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	int selectedRow = [tableView selectedRow];
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
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
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

	[pool release];
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