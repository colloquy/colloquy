#import "JVDirectChatPanel.h"

@class JVChatRoomMember;
@class MVChatUser;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const MVFavoritesListDidUpdateNotification;

@interface JVChatRoomPanel : JVDirectChatPanel {
	@protected
	NSMutableArray *_sortedMembers;
	NSMutableArray *_preferredTabCompleteNicknames;
	NSMutableSet *_nextMessageAlertMembers;
	BOOL _kickedFromRoom;
	BOOL _banListSynced;
	NSUInteger _joinCount;
	NSRegularExpression *_membersRegex;
}
- (void) joined;
- (void) parting;

- (void) joinChat:(nullable id) sender;
- (void) partChat:(nullable id) sender;

- (IBAction) toggleFavorites:(nullable id) sender;

- (NSSet *) chatRoomMembersWithName:(NSString *) name;
- (JVChatRoomMember *) firstChatRoomMemberWithName:(NSString *) name;
- (JVChatRoomMember *) chatRoomMemberForUser:(MVChatUser *) user;
@property (readonly, strong) JVChatRoomMember *localChatRoomMember;
- (void) resortMembers;

- (void) handleRoomMessageNotification:(NSNotification *) notification;
@end

@interface NSObject (MVChatPluginRoomSupport)
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
