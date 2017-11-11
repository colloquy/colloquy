// Created for Colloquy by Thomas Deniau on 04/05/05.

#import "JVChatTranscriptPanel.h"

@class JVChatTranscript;

@interface JVChatTranscriptBrowserPanel : JVChatTranscriptPanel {
	NSDictionary *_transcripts;
	NSArray *_filteredTranscripts;
	NSMutableSet *_dirtyLogs;

	IBOutlet NSTableView *tableView;
	IBOutlet NSSearchField *searchField;
	IBOutlet NSWindow *window;
	IBOutlet NSTextField *statusText;

	NSInteger _selectedTag;

	BOOL _shouldIndex;

	SKIndexRef _logsIndex;
	SKSearchGroupRef _searchGroup;
}
+ (JVChatTranscriptBrowserPanel *) sharedBrowser;

- (IBAction) search:(id) sender;
- (IBAction) showBrowser:(id) sender;
- (IBAction) changeCriterion:(id) sender;

- (void) markDirty:(JVChatTranscript *) transcript;
@end
