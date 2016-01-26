#import "JVChatTranscriptPanel.h"

NS_ASSUME_NONNULL_BEGIN

@interface JVSmartTranscriptPanel : JVChatTranscriptPanel <NSCoding, NSTableViewDataSource, NSTableViewDelegate> {
	IBOutlet NSWindow *settingsSheet;
	IBOutlet NSTableView *subviewTableView;
	IBOutlet NSPopUpButton *operation;
	IBOutlet NSButton *ignoreCase;
	IBOutlet NSTextField *titleField;
	BOOL _settingsNibLoaded;
	NSMutableArray *_editingRules;
	NSMutableArray *_rules;
	NSString *_title;
	NSUInteger _operation;
	BOOL _ignoreCase;
	BOOL _isActive;
	NSUInteger _newMessages;
	NSUInteger _origSheetHeight;
}
- (instancetype) init NS_DESIGNATED_INITIALIZER;
- (nullable instancetype) initWithSettings:(nullable NSDictionary *) settings;

- (NSComparisonResult) compare:(JVSmartTranscriptPanel *) panel;

@property (readonly, copy) NSMutableArray *rules;

@property (readonly) NSUInteger newMessagesWaiting;
- (void) matchMessage:(JVChatMessage *) message fromView:(id <JVChatViewController>) view;

- (IBAction) editSettings:(nullable id) sender;
- (IBAction) closeEditSettingsSheet:(nullable id) sender;
- (IBAction) saveSettings:(nullable id) sender;

- (IBAction) addRow:(nullable id) sender;
- (IBAction) removeRow:(nullable id) sender;
@end

NS_ASSUME_NONNULL_END
