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
- (void) setParent:(JVChatRoom *) parent;

- (MVChatConnection *) connection;

- (void) setMemberName:(NSString *) name;
- (NSString *) memberName;
- (JVBuddy *) buddy;

- (void) setVoice:(BOOL) voice;
- (BOOL) voice;

- (void) setOperator:(BOOL) operator;
- (BOOL) operator;

- (BOOL) isLocalUser;
@end

@interface JVChatRoomMember (JVChatRoomMemberScripting) <JVChatListItemScripting>
- (NSNumber *) uniqueIdentifier;
@end