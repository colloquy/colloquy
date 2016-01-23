#import "JVChatWindowController.h"

@class JVChatRoomPanel;
@class MVChatConnection;
@class MVChatUser;
@class JVBuddy;

@interface JVChatRoomMember : NSObject <JVChatListItem, JVChatListItemScripting> {
	__weak JVChatRoomPanel *_room;
	MVChatUser *_user;

	// Custom ban ivars
	BOOL _nibLoaded;
	IBOutlet NSTextField *banTitle;
	IBOutlet NSTextField *firstTitle;
	IBOutlet NSTextField *secondTitle;
	IBOutlet NSTextField *firstField;
	IBOutlet NSTextField *secondField;
	IBOutlet NSButton *banButton;
	IBOutlet NSButton *cancelButton;
	IBOutlet NSWindow *banWindow;
}
- (instancetype) initWithRoom:(JVChatRoomPanel *) room andUser:(MVChatUser *) user;
- (instancetype) initLocalMemberWithRoom:(JVChatRoomPanel *) room;

- (NSComparisonResult) compare:(JVChatRoomMember *) member;
- (NSComparisonResult) compareUsingStatus:(JVChatRoomMember *) member;
- (NSComparisonResult) compareUsingBuddyStatus:(JVChatRoomMember *) member;

@property (readonly, strong) JVChatRoomPanel *room;
@property (readonly, strong) MVChatConnection *connection;
@property (readonly, strong) MVChatUser *user;
@property (readonly, strong) JVBuddy *buddy;

@property (readonly, copy) NSString *displayName;
@property (readonly, copy) NSString *nickname;
@property (readonly, copy) NSString *realName;
@property (readonly, copy) NSString *username;
@property (readonly, copy) NSString *address;
@property (readonly, copy) NSString *hostmask;

@property (readonly) BOOL voice;
@property (readonly) BOOL quieted;
@property (readonly) BOOL operator;
@property (readonly) BOOL halfOperator;
@property (readonly) BOOL roomAdministrator;
@property (readonly) BOOL roomFounder;
@property (readonly) BOOL serverOperator;
@property (getter=isLocalUser, readonly) BOOL localUser;

@property (readonly, copy) NSString *xmlDescription;
- (NSString *) xmlDescriptionWithTagName:(NSString *) tag;

- (IBAction) startChat:(id) sender;
- (IBAction) sendFile:(id) sender;
- (IBAction) addBuddy:(id) sender;

- (IBAction) toggleOperatorStatus:(id) sender;
- (IBAction) toggleHalfOperatorStatus:(id) sender;
- (IBAction) toggleVoiceStatus:(id) sender;
- (IBAction) toggleQuietedStatus:(id) sender;

- (IBAction) kick:(id) sender;
- (IBAction) ban:(id) sender;
- (IBAction) customKick:(id) sender;
- (IBAction) customBan:(id) sender;
- (IBAction) kickban:(id) sender;
- (IBAction) customKickban:(id) sender;

- (IBAction) closeKickSheet:(id) sender;
- (IBAction) closeBanSheet:(id) sender;
- (IBAction) closeKickbanSheet:(id) sender;
- (IBAction) cancelSheet:(id) sender;
@end

@interface JVChatRoomMember (Private)
- (void) _detach;
- (void) _refreshIcon:(NSNotification *) notification;
- (NSString *) _selfCompositeName;
- (NSString *) _selfStoredNickname;
@end
