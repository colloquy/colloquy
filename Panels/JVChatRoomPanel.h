#import "JVDirectChatPanel.h"

@class JVChatRoomMember;
@class MVChatUser;

@interface JVChatRoomPanel : JVDirectChatPanel {
	@protected
	NSMutableArray *_sortedMembers;
	NSMutableArray *_preferredTabCompleteNicknames;
	NSMutableSet *_nextMessageAlertMembers;
	BOOL _kickedFromRoom;
	BOOL _inRoom;
	BOOL _keepAfterPart;
	BOOL _banListSynced;
	unsigned _joinCount;
}
- (void) joined;
- (void) parting;

- (void) joinChat:(id) sender;
- (void) partChat:(id) sender;

- (IBAction) addToFavorites:(id) sender;

- (BOOL) keepAfterPart;
- (void) setKeepAfterPart:(BOOL) keep;

- (NSSet *) chatRoomMembersWithName:(NSString *) name;
- (JVChatRoomMember *) firstChatRoomMemberWithName:(NSString *) name;
- (JVChatRoomMember *) chatRoomMemberForUser:(MVChatUser *) user;
- (JVChatRoomMember *) localChatRoomMember;
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
