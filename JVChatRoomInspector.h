#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>
#import "JVChatRoom.h"
#import "JVInspectorController.h"

@class NSView;
@class NSPopUpButton;
@class NSButtonCell;
@class NSButton;
@class NSTextField;
@class NSTextView;
@class NSProgressIndicator;

@interface JVChatRoom (JVChatRoomInspection) <JVInspection>
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
	IBOutlet NSProgressIndicator *loadProgress;
	JVChatRoom *_room;
	BOOL _nibLoaded;
}
- (id) initWithRoom:(JVChatRoom *) room;
- (IBAction) changeChatOption:(id) sender;
@end
