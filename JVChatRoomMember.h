#import <Foundation/NSObject.h>
#import "JVChatWindowController.h"

@class JVChatRoom;
@class NSString;
@class MVChatConnection;
@class JVBuddy;

@interface JVChatRoomMember : NSObject <JVChatListItem> {
	JVChatRoom *_parent;
	NSString *_memberName;
	JVBuddy *_buddy;
	BOOL _operator;
	BOOL _voice;
}
- (void) setParent:(id <JVChatListItem>) parent;

- (MVChatConnection *) connection;

- (void) setMemberName:(NSString *) name;
- (NSString *) memberName;

- (void) setVoice:(BOOL) voice;
- (void) setOperator:(BOOL) operator;	
@end
