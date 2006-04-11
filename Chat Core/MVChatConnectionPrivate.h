#import "MVChatConnection.h"

@interface MVChatConnection (MVChatConnectionPrivate)
- (void) _willConnect;
- (void) _didConnect;
- (void) _didNotConnect;
- (void) _willDisconnect;
- (void) _didDisconnect;
- (void) _postError:(NSError *) error;
- (void) _setStatus:(MVChatConnectionStatus) status;

- (void) _addJoinedRoom:(MVChatRoom *) room;
- (void) _removeJoinedRoom:(MVChatRoom *) room;

- (unsigned int) _watchRulesMatchingUser:(MVChatUser *) user;
- (void) _sendPossibleOnlineNotificationForUser:(MVChatUser *) user;
- (void) _sendPossibleOfflineNotificationForUser:(MVChatUser *) user;
@end
