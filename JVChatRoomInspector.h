#import "JVChatRoomPanel.h"
#import "JVInspectorController.h"


@interface JVChatRoomPanel (JVChatRoomInspection) <JVInspection>
- (id <JVInspector>) inspector;
@end

@interface JVChatRoomInspector : NSObject <JVInspector> {
	IBOutlet NSView *view;
	IBOutlet NSTextField *nameField;
	IBOutlet NSTextField *infoField;
	IBOutlet NSPopUpButton *encodingSelection;
	IBOutlet NSPopUpButton *styleSelection;
	IBOutlet NSPopUpButton *emoticonSelection;
	IBOutlet NSButtonCell *privateRoom;
	IBOutlet NSButtonCell *secretRoom;
	IBOutlet NSButtonCell *inviteOnly;
	IBOutlet NSButtonCell *noOutside;
	IBOutlet NSButtonCell *moderated;
	IBOutlet NSButtonCell *topicChangeable;
	IBOutlet NSButton *limitMembers;
	IBOutlet NSTextField *memberLimit;
	IBOutlet NSButton *requiresPassword;
	IBOutlet NSTextField *password;
	IBOutlet NSTextView *topic;
	IBOutlet NSButton *saveTopic;
	IBOutlet NSButton *resetTopic;
	IBOutlet NSTableView *banRules;
	IBOutlet NSButton *newBanButton;
	IBOutlet NSButton *deleteBanButton;
	IBOutlet NSButton *editBanButton;
	JVChatRoomPanel *_room;
	NSMutableArray *_latestBanList;
	BOOL _nibLoaded;
}
- (id) initWithRoom:(JVChatRoomPanel *) room;

- (IBAction) changeChatOption:(id) sender;
- (IBAction) refreshBanList:(id) sender;

- (IBAction) saveTopic:(id) sender;
- (IBAction) resetTopic:(id) sender;

- (IBAction) newBanRule:(id) sender;
- (IBAction) deleteBanRule:(id) sender;
- (IBAction) editBanRule:(id) sender;
@end
