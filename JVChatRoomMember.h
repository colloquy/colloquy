#import <Foundation/NSObject.h>
#import "JVChatWindowController.h"

@class JVChatRoom;
@class NSString;
@class MVChatConnection;
@class JVBuddy;

@interface JVChatRoomMember : NSObject <JVChatListItem> {
	JVChatRoom *_parent;
	NSString *_nickname;
	JVBuddy *_buddy;
	BOOL _operator;
	BOOL _voice;
}
- (id) initWithRoom:(JVChatRoom *) room andNickname:(NSString *) name;

- (NSComparisonResult) compare:(JVChatRoomMember *) member;
- (NSComparisonResult) compareUsingStatus:(JVChatRoomMember *) member;
- (NSComparisonResult) compareUsingBuddyStatus:(JVChatRoomMember *) member;

- (MVChatConnection *) connection;
- (NSString *) nickname;
- (JVBuddy *) buddy;

- (BOOL) voice;
- (BOOL) operator;
- (BOOL) isLocalUser;

- (IBAction) startChat:(id) sender;
- (IBAction) sendFile:(id) sender;

- (IBAction) toggleOperatorStatus:(id) sender;
- (IBAction) toggleVoiceStatus:(id) sender;
- (IBAction) kick:(id) sender;
@end

#pragma mark -

@interface JVChatRoomMember (JVChatMemberPrivate)
- (NSString *) _selfStoredNickname;
- (NSString *) _selfCompositeName;

- (void) _setNickname:(NSString *) name;
- (void) _setVoice:(BOOL) voice;
- (void) _setOperator:(BOOL) operator;
@end

#pragma mark -

@interface JVChatRoomMember (JVChatRoomMemberScripting) <JVChatListItemScripting>
- (NSNumber *) uniqueIdentifier;
@end