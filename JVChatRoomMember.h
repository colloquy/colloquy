#import "JVChatWindowController.h"

@class JVChatRoomPanel;
@class MVChatConnection;
@class MVChatUser;
@class JVBuddy;

@interface JVChatRoomMember : NSObject <JVChatListItem> {
	JVChatRoomPanel *_parent;
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
- (id) initWithRoom:(JVChatRoomPanel *) room andUser:(MVChatUser *) user;
- (id) initLocalMemberWithRoom:(JVChatRoomPanel *) room;

- (NSComparisonResult) compare:(JVChatRoomMember *) member;
- (NSComparisonResult) compareUsingStatus:(JVChatRoomMember *) member;
- (NSComparisonResult) compareUsingBuddyStatus:(JVChatRoomMember *) member;

- (JVChatRoomPanel *) room;
- (MVChatConnection *) connection;
- (MVChatUser *) user;
- (JVBuddy *) buddy;

- (NSString *) displayName;
- (NSString *) nickname;
- (NSString *) realName;
- (NSString *) username;
- (NSString *) address;
- (NSString *) hostmask;

- (BOOL) voice;
- (BOOL) quieted;
- (BOOL) operator;
- (BOOL) halfOperator;
- (BOOL) roomFounder;
- (BOOL) serverOperator;
- (BOOL) isLocalUser;

- (NSString *) xmlDescription;
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

#pragma mark -

@interface JVChatRoomMember (JVChatRoomMemberScripting) <JVChatListItemScripting>
- (NSNumber *) uniqueIdentifier;
@end