@class JVChatTranscriptPanel;
@class JVChatMessage;

@interface JVTranscriptFindWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate> {
	@private
	IBOutlet NSTableView *subviewTableView;
	IBOutlet NSPopUpButton *operation;
	IBOutlet NSButton *scrollbackOnly;
	IBOutlet NSButton *ignoreCase;
	IBOutlet NSTextField *resultCount;
	IBOutlet NSProgressIndicator *resultProgress;
	IBOutlet NSView *hiddenResults;
	IBOutlet NSTextField *hiddenResultsCount;
	NSMutableArray *_rules;
	NSMutableArray *_results;
	NSUInteger _lastMessageIndex;
	BOOL _findPasteboardNeedsUpdated;
}
+ (JVTranscriptFindWindowController *) sharedController;

- (JVChatTranscriptPanel *) focusedChatTranscriptPanel;

- (IBAction) addRow:(id) sender;
- (IBAction) removeRow:(id) sender;

- (IBAction) findNext:(id) sender;
- (IBAction) findPrevious:(id) sender;
@end
