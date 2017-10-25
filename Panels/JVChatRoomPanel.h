#import <Cocoa/Cocoa.h>
#import "JVDirectChatPanel.h"
#import <ChatCore/MVMessaging.h>

@class JVChatRoomMember;
@class MVChatUser;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const MVFavoritesListDidUpdateNotification;

COLLOQUY_EXPORT
@interface JVChatRoomPanel : JVDirectChatPanel {
	@protected
	NSMutableArray<JVChatRoomMember *> *_sortedMembers;
	NSMutableArray *_preferredTabCompleteNicknames;
	NSMutableSet *_nextMessageAlertMembers;
	BOOL _kickedFromRoom;
	BOOL _banListSynced;
	NSUInteger _joinCount;
	NSRegularExpression *_membersRegex;
}
- (void) joined;
- (void) parting;

- (IBAction) joinChat:(nullable id) sender;
- (IBAction) partChat:(nullable id) sender;

- (IBAction) toggleFavorites:(nullable id) sender;

- (NSSet<JVChatRoomMember*> *) chatRoomMembersWithName:(NSString *) name;
- (nullable JVChatRoomMember *) firstChatRoomMemberWithName:(NSString *) name;
- (nullable JVChatRoomMember *) chatRoomMemberForUser:(MVChatUser *) user;
@property (readonly, strong, nullable) JVChatRoomMember *localChatRoomMember;
- (void) resortMembers;

- (void) handleRoomMessageNotification:(NSNotification *) notification;
@end

@protocol MVChatPluginRoomSupport <MVChatPlugin>
@optional
- (void) memberJoined:(JVChatRoomMember *) member inRoom:(JVChatRoomPanel *) room;
- (void) memberParted:(JVChatRoomMember *) member fromRoom:(JVChatRoomPanel *) room forReason:(NSAttributedString *) reason;
- (void) memberKicked:(JVChatRoomMember *) member fromRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by forReason:(NSAttributedString *) reason;

- (void) joinedRoom:(JVChatRoomPanel *) room;
- (void) partingFromRoom:(JVChatRoomPanel *) room;
- (void) kickedFromRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) by forReason:(NSAttributedString *) reason;

- (void) userBricked:(MVChatUser *) user inRoom:(JVChatRoomPanel *) room;

- (void) topicChangedTo:(NSAttributedString *) topic inRoom:(JVChatRoomPanel *) room by:(JVChatRoomMember *) member;
@end

NS_ASSUME_NONNULL_END
