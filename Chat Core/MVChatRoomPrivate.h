#import "MVChatRoom.h"

@interface MVChatRoom (MVChatRoomPrivate)
- (void) _updateMemberUser:(MVChatUser *) user fromOldUniqueIdentifier:(id) identifier;
- (void) _clearMemberUsers;
- (void) _clearBannedUsers;
- (void) _addMemberUser:(MVChatUser *) user;
- (void) _removeMemberUser:(MVChatUser *) user;
- (void) _addBanForUser:(MVChatUser *) user;
- (void) _removeBanForUser:(MVChatUser *) user;
- (void) _setModes:(unsigned long) modes forMemberUser:(MVChatUser *) user;
- (void) _setMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user;
- (void) _removeMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user;
- (void) _setMode:(MVChatRoomMode) mode withAttribute:(id) attribute;
- (void) _removeMode:(MVChatRoomMode) mode;
- (void) _clearModes;
- (void) _setDateJoined:(NSDate *) date;
- (void) _setDateParted:(NSDate *) date;
- (void) _setTopic:(NSData *) topic byAuthor:(MVChatUser *) author withDate:(NSDate *) date;
@end
