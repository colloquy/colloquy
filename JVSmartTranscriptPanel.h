#import "JVChatTranscriptPanel.h"

@interface JVSmartTranscriptPanel : JVChatTranscriptPanel {
	IBOutlet NSWindow *settingsSheet;
	IBOutlet NSTableView *subviewTableView;
	IBOutlet NSPopUpButton *operation;
	IBOutlet NSButton *ignoreCase;
	BOOL _settingsNibLoaded;
	NSMutableDictionary *_settings;
	NSMutableArray *_rules;
	NSString *_title;
	BOOL _isActive;
	unsigned long _newMessages;
}
- (id) initWithSettings:(NSDictionary *) settings;

- (void) matchMessage:(JVChatMessage *) message fromView:(id <JVChatViewController>) view;

- (IBAction) editSettings:(id) sender;
- (IBAction) closeEditSettingsSheet:(id) sender;
- (IBAction) saveSettings:(id) sender;

- (IBAction) addRow:(id) sender;
- (IBAction) removeRow:(id) sender;	
@end
