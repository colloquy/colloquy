#import "JVDirectChat.h"
#import <AppKit/NSNibDeclarations.h>

@class NSTextField;
@class NSMutableDictionary;
@class NSMutableArray;
@class NSData;
@class NSString;

@interface JVChatRoom : JVDirectChat {
	@protected
	IBOutlet NSTextField *topicLine;
	NSMutableDictionary *_members;
	NSMutableArray *_sortedMembers;
	NSData *_topic;
	NSString *_topicAuth;
	BOOL _invalidateMembers;
}
- (void) addMemberToChat:(NSString *) member asPreviousMember:(BOOL) previous;
- (void) updateMember:(NSString *) member withInfo:(NSDictionary *) info;
- (void) removeChatMember:(NSString *) member withReason:(NSData *) reason;
- (void) changeChatMember:(NSString *) member to:(NSString *) nick;
- (void) changeSelfTo:(NSString *) nick;

- (void) promoteChatMember:(NSString *) member by:(NSString *) by;
- (void) demoteChatMember:(NSString *) member by:(NSString *) by;
- (void) voiceChatMember:(NSString *) member by:(NSString *) by;
- (void) devoiceChatMember:(NSString *) member by:(NSString *) by;

- (void) chatMember:(NSString *) member kickedBy:(NSString *) by forReason:(NSData *) reason;
- (void) kickedFromChatBy:(NSString *) by forReason:(NSData *) reason;

- (void) changeTopic:(NSData *) topic by:(NSString *) author;
@end
