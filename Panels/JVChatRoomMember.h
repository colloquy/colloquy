#import <Cocoa/Cocoa.h>
#import "JVChatWindowController.h"

@class JVChatRoomPanel;
@class MVChatConnection;
@class MVChatUser;
@class JVBuddy;

NS_ASSUME_NONNULL_BEGIN

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
- (instancetype) initWithRoom:(JVChatRoomPanel *) room andUser:(MVChatUser *) user NS_DESIGNATED_INITIALIZER;
- (instancetype) initLocalMemberWithRoom:(JVChatRoomPanel *) room;
- (instancetype) init UNAVAILABLE_ATTRIBUTE;

- (NSComparisonResult) compare:(JVChatRoomMember *) member;
- (NSComparisonResult) compareUsingStatus:(JVChatRoomMember *) member;
- (NSComparisonResult) compareUsingBuddyStatus:(JVChatRoomMember *) member;

@property (readonly, strong) JVChatRoomPanel *room;
@property (readonly, strong) MVChatConnection *connection;
@property (readonly, strong) MVChatUser *user;
@property (readonly, strong, nullable) JVBuddy *buddy;

@property (readonly, copy) NSString *displayName;
@property (readonly, copy) NSString *nickname;
@property (readonly, copy) NSString *realName;
@property (readonly, copy) NSString *username;
@property (readonly, copy) NSString *address;
@property (readonly, copy, nullable) NSString *hostmask;

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

- (IBAction) startChat:(nullable id) sender;
- (IBAction) sendFile:(nullable id) sender;
- (IBAction) addBuddy:(nullable id) sender;

- (IBAction) toggleOperatorStatus:(nullable id) sender;
- (IBAction) toggleHalfOperatorStatus:(nullable id) sender;
- (IBAction) toggleVoiceStatus:(nullable id) sender;
- (IBAction) toggleQuietedStatus:(nullable id) sender;

- (IBAction) kick:(nullable id) sender;
- (IBAction) ban:(nullable id) sender;
- (IBAction) customKick:(nullable id) sender;
- (IBAction) customBan:(nullable id) sender;
- (IBAction) kickban:(nullable id) sender;
- (IBAction) customKickban:(nullable id) sender;

- (IBAction) closeKickSheet:(nullable id) sender;
- (IBAction) closeBanSheet:(nullable id) sender;
- (IBAction) closeKickbanSheet:(nullable id) sender;
- (IBAction) cancelSheet:(nullable id) sender;
@end

@interface JVChatRoomMember (Private)
- (void) _detach;
- (void) _refreshIcon:(NSNotification *) notification;
- (NSString *) _selfCompositeName;
- (NSString *) _selfStoredNickname;
@end

NS_ASSUME_NONNULL_END
