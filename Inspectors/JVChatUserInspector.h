#import "JVChatRoomMember.h"
#import "JVDirectChatPanel.h"
#import "JVInspectorController.h"

@interface JVDirectChatPanel (JVDirectChatPanelInspection) <JVInspection>
- (id <JVInspector>) inspector;
@end

@interface JVChatRoomMember (JVChatRoomMemberInspection) <JVInspection>
- (id <JVInspector>) inspector;
@end

@interface MVChatUser (MVChatUserInspection) <JVInspection>
- (id <JVInspector>) inspector;
@end

@interface JVChatUserInspector : NSObject <JVInspector> {
	IBOutlet NSView *view;
	IBOutlet NSImageView *image;
	IBOutlet NSTextField *nickname;
	IBOutlet NSProgressIndicator *progress;
	IBOutlet NSTextField *class;
	IBOutlet NSTextField *away;
	IBOutlet NSTextField *address;
	IBOutlet NSTextField *hostname;
	IBOutlet NSTextField *username;
	IBOutlet NSTextField *realName;
	IBOutlet NSTextField *server;
	IBOutlet NSTextField *rooms;
	IBOutlet NSTextField *connected;
	IBOutlet NSTextField *idle;
	IBOutlet NSTextField *ping;
	IBOutlet NSButton *sendPing;
	IBOutlet NSTextField *localTime;
	IBOutlet NSButton *requestTime;
	IBOutlet NSTextField *clientInfo;
	IBOutlet NSButton *requestInfo;
	MVChatUser *_user;
	NSTimer *_localTimeUpdateTimer;
	NSTimer *_updateTimer;
	BOOL _nibLoaded;
	BOOL _addressResolved;
}
- (id) initWithChatUser:(MVChatUser *) user;
- (void) updateLocalTime;

- (IBAction) requestLocalTime:(id) sender;
- (IBAction) requestClientInfo:(id) sender;
@end
