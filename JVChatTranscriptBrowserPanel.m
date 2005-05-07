// Created for Colloquy by Thomas Deniau on 04/05/05.
// Thanks to the Adium project for the interface inspiration.

#import "JVChatTranscriptBrowserPanel.h"
#import "JVChatTranscript.h"
#import "JVStyle.h"
#import "JVStyleView.h"
#import "AvailabilityMacros.h"
#import "MVApplicationController.h"
#import <AGRegex/AGRegex.h>

id sharedBrowser=nil;
NSString *criteria[4]={@"server",@"target",@"session",nil};

@implementation JVChatTranscriptBrowserPanel

+(JVChatTranscriptBrowserPanel *) sharedBrowser
{
	if (sharedBrowser) return sharedBrowser;
	else return [[self alloc] init];
}

-(NSString *)logsPath
{
	return [[[NSUserDefaults standardUserDefaults] stringForKey:@"JVChatTranscriptFolder"] stringByStandardizingPath];
}

-(NSString *)indexPath
{
	return [[@"~/Library/Application Support/Colloquy" stringByExpandingTildeInPath] stringByAppendingPathComponent:@"Transcript Search Index"];
}

-(NSString *)dirtyPath
{
	return [[@"~/Library/Application Support/Colloquy" stringByExpandingTildeInPath] stringByAppendingPathComponent:@"Dirty Transcripts"];
}

-(id)init
{
	if (! sharedBrowser && (self = [super init]))
	{
		NSMutableDictionary *tempDictionary=[NSMutableDictionary dictionary];
		NSString *logs = [self logsPath];
		int org = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatTranscriptFolderOrganization"];
		int session = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatTranscriptSessionHandling"];
		AGRegex *regex;
		NSString *logPath;
		NSDirectoryEnumerator *logsEnum = [[NSFileManager defaultManager] enumeratorAtPath: logs];
	
		switch(org)
		{
			case 0: // all in the same folder, w/server
				regex = [[AGRegex alloc] initWithPattern:@"(?P<target>.*) \\((?P<server>.*\\)) ?(?P<session>.*).colloquyTranscript"]; 
				break;
			case 1: //a folder for each server
				regex = [[AGRegex alloc] initWithPattern:@"(?P<server>.*)/(?P<target>.*) ?(?P<session>.*).colloquyTranscript"];
				break;
			case 2: // a folder for each (server,target)
				regex = [[AGRegex alloc] initWithPattern:@"(?P<target>.*) \\((?P<server>.*)\\)/(.* )?(?P<session>.*).colloquyTranscript"];
				break;
			case 3: // a folder for each server, then for each target
				regex = [[AGRegex alloc] initWithPattern:@"(?P<server>.*)/(?P<target>.*)/(.* )?(?P<session>.*).colloquyTranscript"];
				break;
		}

		if ([[NSFileManager defaultManager] fileExistsAtPath:[self dirtyPath]])
			_dirtyLogs = [[NSKeyedUnarchiver unarchiveObjectWithFile:[self dirtyPath]] retain];
		else _dirtyLogs = [[NSMutableSet alloc] init];
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:[self indexPath]])
		{
			_shouldIndex = NO;
			_logsIndex = SKIndexOpenWithURL((CFURLRef)[NSURL fileURLWithPath:[self indexPath]],NULL,YES);
		}
		else
		{
			_shouldIndex = YES;
			_logsIndex = SKIndexCreateWithURL((CFURLRef)[NSURL fileURLWithPath:[self indexPath]],NULL,kSKIndexInverted,NULL);
		}
		
		CFArrayRef indexes = CFArrayCreate(kCFAllocatorDefault,(void*)&_logsIndex,1,&kCFTypeArrayCallBacks);
		_searchGroup = SKSearchGroupCreate(indexes);
		CFRelease(indexes);
		
		while (logPath = [logsEnum nextObject]) 
		{
			if ([[logPath pathExtension] isEqualToString:@"colloquyTranscript"])
			{
				// analyze the path
				AGRegexMatch *match=[regex findInString:logPath];
				
				NSString *server = [match groupNamed:@"server"];
				NSString *target = [match groupNamed:@"target"];
				NSString *session = [match groupNamed:@"session"];
				NSString *path = [logs stringByAppendingPathComponent:logPath];
				
#ifdef MAC_OS_X_VERSION_10_4
				if( floor( NSAppKitVersionNumber ) == NSAppKitVersionNumber10_3 ) {
					FILE* logsFile = fopen([path fileSystemRepresentation],"r");
					if (logsFile)
					{
						int fd = fileno(logsFile);			
						
						char buffer[1024];
						ssize_t size;
						
						if ((size=fgetxattr(fd,"server",buffer,1023,0,0))>0)
						{
							buffer[size]=0;
							server = [NSString stringWithUTF8String:buffer];
						}
						
						if ((size=fgetxattr(fd,"target",buffer,1023,0,0))>0)
						{
							buffer[size]=0;
							target = [NSString stringWithUTF8String:buffer];
						}
						
						if ((size=fgetxattr(fd,"dateBegan",buffer,1023,0,0))>0)
						{
							buffer[size]=0;
							session = [NSString stringWithUTF8String:buffer];
						}
						
						fclose(logsFile);
					}
				}
#endif
				NSDictionary *d=[NSDictionary dictionaryWithObjectsAndKeys:
									server,@"server",
									target,@"target",
									session,@"session",
									path,@"path",NULL];
				[tempDictionary setObject:d forKey:path];
				if (_shouldIndex) [_dirtyLogs addObject:path];
			}
		}
		_shouldIndex = NO;
		[regex release];
		
		_transcripts = [tempDictionary copy];
		_filteredTranscripts = [[_transcripts allValues] copy];
		_selectedTag=1;
		_nibLoaded=FALSE;
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(beginIndexing:) 
													 name:JVMachineBecameIdleNotification object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(stopIndexing:) 
													 name:JVMachineStoppedIdlingNotification object:nil];
		
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(markDirty:) 
													 name:JVChatTranscriptUpdatedNotification object:nil];
		
		
		_logLock = [[NSLock alloc] init];
		

		
		sharedBrowser = self;

	}
	else [super dealloc];

	return sharedBrowser;
}

-(void)dealloc
{
	[NSKeyedArchiver archiveRootObject:_dirtyLogs 
								toFile:[self dirtyPath]];
		
	[_logLock release];
	[_dirtyLogs release];
	
	SKIndexClose(_logsIndex);
	CFRelease(_searchGroup);
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_filteredTranscripts release];
	[_transcripts release];
	
	[super dealloc];
}

-(IBAction)showBrowser:(id)sender
{
	if (! _nibLoaded) 
	{
		[NSBundle loadNibNamed:@"JVChatTranscriptBrowserPanel" owner:self];
	}
	[window makeKeyAndOrderFront:self];
}

-(NSView *)view
{
	if (! _nibLoaded) [NSBundle loadNibNamed:@"JVChatTranscriptBrowserPanel" owner:self];
	return [window contentView];
}

-(void)awakeFromNib
{
	[super awakeFromNib];
	_nibLoaded=YES;
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [_filteredTranscripts count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{	
	return [[_filteredTranscripts objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]];
}

- (void)tableView:(NSTableView *)aTableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
	NSArray *sorted = [_filteredTranscripts sortedArrayUsingDescriptors:[tableView sortDescriptors]];
	
	int selectedRow = [tableView selectedRow];
	NSDictionary *selected=nil;
	if (selectedRow != -1)
		selected = [_filteredTranscripts objectAtIndex:selectedRow]; 
	
	[_filteredTranscripts release];
	_filteredTranscripts = [sorted retain];
	
	[tableView reloadData];
	if (selected) [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[sorted indexOfObject:selected]]
										 byExtendingSelection:NO];
}

-(IBAction)search:(id)sender
{
	if ([[searchField stringValue] length])
	{
		if (criteria[_selectedTag])
		{
			NSMutableArray *filtered=[NSMutableArray arrayWithCapacity:[_transcripts count]];
			NSEnumerator *tEnum=[_transcripts objectEnumerator];
			NSDictionary *d;
			while (d=[tEnum nextObject])
			{
				if ([[d objectForKey:criteria[_selectedTag]] rangeOfString:[searchField stringValue]].location != NSNotFound)
				{
					[filtered addObject:d];
				}
			}
			[_filteredTranscripts release];
			_filteredTranscripts = [filtered copy];

		}
		else
		{
			NSMutableArray *tempArray = [[NSMutableArray alloc] init];
			
			SKIndexFlush(_logsIndex);
			SKSearchResultsRef results = SKSearchResultsCreateWithQuery(_searchGroup,
																		(CFStringRef)[searchField stringValue],
																		kSKSearchPrefixRanked,
																		[_transcripts count],
																		NULL,NULL);
			
			CFIndex resultCount = SKSearchResultsGetCount(results);
			
			SKDocumentRef   *outDocumentsArray = malloc(sizeof(SKDocumentRef) * resultCount);
			float		*outScoresArray = malloc(sizeof(float) * resultCount);
			CFRange		resultRange = CFRangeMake(0, resultCount);
			
			SKSearchResultsGetInfoInRange(results,resultRange,outDocumentsArray,NULL,outScoresArray);
			int i;
			
			//Process the results
			for(i = 0; i < resultCount; i++)
			{
				CFURLRef url=SKDocumentCopyURL(outDocumentsArray[i]);
				NSString *path=[(NSURL*)url path];
				CFRelease(url);
				
				NSDictionary *theLog = [_transcripts objectForKey:path];
				//NSLog(@"path %@ -> %@",path,theLog);
				[tempArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:
					[theLog objectForKey:@"server"],@"server",
					[theLog objectForKey:@"target"],@"target",
					[theLog objectForKey:@"session"],@"session",
					path,@"path",[NSNumber numberWithFloat:outScoresArray[i]],@"relevancy",NULL]];
			}	 
				
			[_filteredTranscripts release];
			_filteredTranscripts = [tempArray copy];
			//NSLog(@"%@",_filteredTranscripts);
			[tempArray release];
		}
	}
	else 
	{
		[_filteredTranscripts release];
		_filteredTranscripts=[[_transcripts allValues] copy];
	}

	[tableView reloadData];
}

-(IBAction)changeCriterion:(id)sender
{
	int i;
	[[searchField cell] setPlaceholderString:[sender title]];
	_selectedTag = [sender tag];
	for (i=0;i<4;i++)
	{
		[[[searchField menu] itemWithTag:i] setState:(i==_selectedTag)?NSOnState:NSOffState];
	}
	[self search:self];
}

-(void)tableViewSelectionDidChange:(NSNotification *)n
{
	int selectedRow=[tableView selectedRow];
	if (selectedRow != -1)
	{
		[_transcript release];
		_transcript=[[JVChatTranscript alloc] initWithContentsOfFile:[[_filteredTranscripts objectAtIndex:selectedRow] objectForKey:@"path"]];
		[display setTranscript:_transcript];
		[self setSearchQuery:[searchField stringValue]];
		[display reloadCurrentStyle];
	}
}

-(void)beginIndexing:(NSNotification *)n
{
	//NSLog(@"oooh good time to index");
	_shouldIndex = YES;
	[NSThread detachNewThreadSelector:@selector(indexingThread) toTarget:self withObject:nil];
}

-(void)indexingThread
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString *path;
	
	while (_shouldIndex && (path=[_dirtyLogs anyObject]))
	{
		[path retain];
		[_logLock lock];
		[_dirtyLogs removeObject:path];
		[_logLock unlock];
		
				//NSLog(@"Indexing:%@",path);
		SKDocumentRef document = SKDocumentCreateWithURL((CFURLRef)[NSURL fileURLWithPath:path]);
		NSString *toIndex = [[NSString alloc] initWithContentsOfFile:path]; // FIXME strip xml (w/o NSXMLDocument...) ?
		SKIndexAddDocumentWithText(_logsIndex,document,(CFStringRef)toIndex,YES);
		CFRelease(document);
		[toIndex release];
		[path release];
		
		//NSLog(@"I have indexed:%@",path);
	}
	
	SKIndexFlush(_logsIndex);
	
//	NSLog(@"Index finished or stopped.");
	
	[pool release];
}

-(void)stopIndexing:(NSNotification *)n
{
	//NSLog(@"STOP IT");
	_shouldIndex = NO;
}

-(void)markDirty:(id)log
{
	if ([log isKindOfClass:[NSNotification class]]) log=[[log object] filePath];
	
	//NSLog(@"Marking %@ as dirty", log);
	[_logLock lock]; // might be used from multiple threads
	[_dirtyLogs addObject:log];
	[_logLock unlock];
}


@end
