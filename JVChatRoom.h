#import "JVDirectChat.h"

@class JVChatRoomMember;
@class MVChatUser;

@interface JVChatRoom : JVDirectChat {
	@protected
	IBOutlet NSTextView *topicLine;

	NSMutableArray *_sortedMembers;
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

- (BOOL) keepAfterPart;
- (void) setKeepAfterPart:(BOOL) keep;

- (JVChatRoomMember *) firstChatRoomMemberWithName:(NSString *) name;
- (JVChatRoomMember *) chatRoomMemberForUser:(MVChatUser *) user;
- (JVChatRoomMember *) localChatRoomMember;
- (void) resortMembers;
@end

@interface NSObject (MVChatPluginRoomSupport)
- (void) memberJoined:(JVChatRoomMember *) member inRoom:(JVChatRoom *) room;
- (void) memberParted:(JVChatRoomMember *) member fromRoom:(JVChatRoom *) room forReason:(NSAttributedString *) reason;
- (void) memberKicked:(JVChatRoomMember *) member fromRoom:(JVChatRoom *) room by:(JVChatRoomMember *) by forReason:(NSAttributedString *) reason;

- (void) joinedRoom:(JVChatRoom *) room;
- (void) partingFromRoom:(JVChatRoom *) room;
- (void) kickedFromRoom:(JVChatRoom *) room by:(JVChatRoomMember *) by forReason:(NSAttributedString *) reason;

- (void) topicChangedTo:(NSAttributedString *) topic inRoom:(JVChatRoom *) room by:(JVChatRoomMember *) member;
@end