#import "MVChatRoom.h"
#include <libsilcclient/client.h>
#include <libsilc/silcincludes.h>

@class MVSILCChatConnection;

@interface MVSILCChatRoom : MVChatRoom {
	SilcChannelEntry _channelEntry;
}
- (id) initWithChannelEntry:(SilcChannelEntry) channelEntry andConnection:(MVSILCChatConnection *) connection;

- (SilcChannelEntry) _getChannelEntry;

- (void) _setChannelUserMode:(unsigned int)SilcMode forUser:(MVChatUser *) user;
- (void) _removeChannelUserMode:(unsigned int)SilcMode forUser:(MVChatUser *) user;
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
- (void) _setAttribute:(id) attribute forKey:(id) key;
@end
