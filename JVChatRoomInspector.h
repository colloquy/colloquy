#import "JVChatRoomPanel.h"
#import "JVInspectorController.h"


@interface JVChatRoomPanel (JVChatRoomInspection) <JVInspection>
- (id <JVInspector>) inspector;
@end

@interface JVChatRoomInspector : NSObject <JVInspector> {
	IBOutlet NSView *view;
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
	JVChatRoomPanel *_room;
	BOOL _nibLoaded;
}
- (id) initWithRoom:(JVChatRoomPanel *) room;
- (IBAction) changeChatOption:(id) sender;
@end
