#import "MVChatRoom.h"

@class MVIRCChatConnection;

@interface MVIRCChatRoom : MVChatRoom {}
- (id) initWithName:(NSString *) name andConnection:(MVIRCChatConnection *) connection;
@end

#pragma mark -

@interface MVChatRoom (MVChatRoomPrivate)
- (void) _updateMemberUser:(MVChatUser *) user fromOldNickname:(NSString *) oldNickname;
- (void) _clearMemberUsers;
- (void) _clearBannedUsers;
- (void) _addMemberUser:(MVChatUser *) user;
- (void) _removeMemberUser:(MVChatUser *) user;
- (void) _addBanForUser:(MVChatUser *) user;
- (void) _removeBanForUser:(MVChatUser *) user;
- (void) _setMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user;
- (void) _removeMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user;
- (void) _setMode:(MVChatRoomMode) mode withAttribute:(id) attribute;
- (void) _removeMode:(MVChatRoomMode) mode;
- (void) _clearModes;
- (void) _setDateJoined:(NSDate *) date;
- (void) _setDateParted:(NSDate *) date;
- (void) _setTopic:(NSData *) topic byAuthor:(MVChatUser *) author withDate:(NSDate *) date;
@end
