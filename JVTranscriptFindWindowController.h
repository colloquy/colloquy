@class JVChatTranscript;
@class JVChatMessage;

@interface JVTranscriptFindWindowController : NSWindowController {
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
	JVChatMessage *_lastFoundMessage;
	BOOL _findPasteboardNeedsUpdated;
}
+ (JVTranscriptFindWindowController *) sharedController;

- (JVChatTranscript *) focusedChatTranscript;

- (IBAction) addRow:(id) sender;
- (IBAction) removeRow:(id) sender;

- (IBAction) findNext:(id) sender;
- (IBAction) findPrevious:(id) sender;
@end
