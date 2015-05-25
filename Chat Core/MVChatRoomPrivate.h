#import "MVChatRoom.h"

NS_ASSUME_NONNULL_BEGIN

@interface MVChatRoom (MVChatRoomPrivate)
- (void) _connectionDestroyed;
- (void) _updateMemberUser:(MVChatUser *) user fromOldUniqueIdentifier:(id) identifier;
- (void) _clearMemberUsers;
- (void) _clearBannedUsers;
- (void) _addMemberUser:(MVChatUser *) user;
- (void) _removeMemberUser:(MVChatUser *) user;
- (void) _addBanForUser:(MVChatUser *) user;
- (void) _removeBanForUser:(MVChatUser *) user;
- (void) _setModes:(NSUInteger) modes forMemberUser:(MVChatUser *) user;
- (void) _setMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user;
- (void) _removeMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user;
- (void) _setDisciplineModes:(NSUInteger) modes forMemberUser:(MVChatUser *) user;
- (void) _setDisciplineMode:(MVChatRoomMemberDisciplineMode) mode forMemberUser:(MVChatUser *) user;
- (void) _removeDisciplineMode:(MVChatRoomMemberDisciplineMode) mode forMemberUser:(MVChatUser *) user;
- (void) _setMode:(MVChatRoomMode) mode withAttribute:(id __nullable) attribute;
- (void) _removeMode:(MVChatRoomMode) mode;
- (void) _clearModes;
- (void) _setDateJoined:(NSDate * __nullable) date;
- (void) _setDateParted:(NSDate * __nullable) date;
- (void) _setTopic:(NSData *) topic;
- (void) _setTopicAuthor:(MVChatUser *) author;
- (void) _setTopicDate:(NSDate *) date;
@end

NS_ASSUME_NONNULL_END
