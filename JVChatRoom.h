#import "JVDirectChat.h"
#import <AppKit/NSNibDeclarations.h>

@class NSTextView;
@class WebView;
@class NSMutableDictionary;
@class NSMutableArray;
@class NSData;
@class NSString;
@class JVChatRoomMember;

@interface JVChatRoom : JVDirectChat {
	@protected
	IBOutlet NSTextView *topicLine;

	NSMutableDictionary *_members;
	NSMutableArray *_sortedMembers;
	NSAttributedString *_topicAttributed;
	NSData *_topic;
	NSString *_topicAuth;

	BOOL _kickedFromRoom;
	BOOL _inRoom;
}
- (void) joined;
- (void) parting;

- (void) joinChat:(id) sender;
- (void) partChat:(id) sender;

- (void) addExistingMembersToChat:(NSArray *) members;
- (void) addMemberToChat:(NSString *) member withInformation:(NSDictionary *) info;
- (void) removeChatMember:(NSString *) member withReason:(NSData *) reason;
- (void) changeChatMember:(NSString *) member to:(NSString *) nick;

- (void) promoteChatMember:(NSString *) member by:(NSString *) by;
- (void) demoteChatMember:(NSString *) member by:(NSString *) by;
- (void) voiceChatMember:(NSString *) member by:(NSString *) by;
- (void) devoiceChatMember:(NSString *) member by:(NSString *) by;

- (void) chatMember:(NSString *) member kickedBy:(NSString *) by forReason:(NSData *) reason;
- (void) kickedFromChatBy:(NSString *) by forReason:(NSData *) reason;

- (void) changeTopic:(NSData *) topic by:(NSString *) author displayChange:(BOOL) showChange;
- (NSAttributedString *) topic;

- (JVChatRoomMember *) chatRoomMemberWithName:(NSString *) name;
- (void) resortMembers;
@end

@interface NSObject (MVChatPluginRoomSupport)
- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toRoom:(JVChatRoom *) room;

- (void) processMessage:(NSMutableData *) message asAction:(BOOL) action fromMember:(JVChatRoomMember *) member inRoom:(JVChatRoom *) room;
- (void) processMessage:(NSMutableAttributedString *) message asAction:(BOOL) action toRoom:(JVChatRoom *) room;

- (void) memberJoined:(JVChatRoomMember *) member inRoom:(JVChatRoom *) room;
- (void) memberParted:(JVChatRoomMember *) member fromRoom:(JVChatRoom *) room forReason:(NSString *) reason;
- (void) memberKicked:(JVChatRoomMember *) member fromRoom:(JVChatRoom *) room by:(JVChatRoomMember *) by forReason:(NSString *) reason;

- (void) memberPromoted:(JVChatRoomMember *) member inRoom:(JVChatRoom *) room by:(JVChatRoomMember *) by;
- (void) memberDemoted:(JVChatRoomMember *) member inRoom:(JVChatRoom *) room by:(JVChatRoomMember *) by;
- (void) memberVoiced:(JVChatRoomMember *) member inRoom:(JVChatRoom *) room by:(JVChatRoomMember *) by;
- (void) memberDevoiced:(JVChatRoomMember *) member inRoom:(JVChatRoom *) room by:(JVChatRoomMember *) by;

- (void) joinedRoom:(JVChatRoom *) room;
- (void) partingFromRoom:(JVChatRoom *) room;
- (void) kickedFromRoom:(JVChatRoom *) room by:(JVChatRoomMember *) by forReason:(NSString *) reason;

- (void) topicChangedTo:(NSString *) topic inRoom:(JVChatRoom *) room by:(JVChatRoomMember *) member;
@end