// Created for Colloquy by Thomas Deniau on 04/05/05.

#import "JVChatTranscriptPanel.h"

@interface JVChatTranscriptBrowserPanel : JVChatTranscriptPanel {
	NSDictionary *_transcripts;
	NSArray *_filteredTranscripts;
	
	IBOutlet NSTableView *tableView;
	IBOutlet NSSearchField *searchField;
	IBOutlet NSWindow *window;
	
	int _selectedTag;
	
	BOOL _shouldIndex;
	
	NSMutableSet *_dirtyLogs;
	NSLock *_logLock;
	
	SKIndexRef _logsIndex;
	SKSearchGroupRef _searchGroup;
	
}

+(JVChatTranscriptBrowserPanel *)sharedBrowser;

-(IBAction)search:(id)sender;
-(IBAction)showBrowser:(id)sender;
-(IBAction)changeCriterion:(id)sender;

-(void)markDirty:(id)log;

@end
