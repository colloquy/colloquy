#import "MVChatConnection.h"

@interface NSThread (NSThreadLeopard)
- (void) cancel;
- (void) setName:(NSString *) name;
@end

#pragma mark -

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
- (void) _markUserAsOnline:(MVChatUser *) user;
- (void) _markUserAsOffline:(MVChatUser *) user;
@end
