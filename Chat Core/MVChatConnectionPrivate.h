#import "MVChatConnection.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSThread (NSThreadLeopard)
- (void) cancel;
- (void) setName:(NSString *) name;
@end

#pragma mark -

@interface MVChatConnection (MVChatConnectionPrivate)
- (void) _systemWillSleep:(NSNotification *) notification;
- (void) _systemDidWake:(NSNotification *) notification;
- (void) _applicationWillTerminate:(NSNotification *) notification;

- (void) _willConnect;
- (void) _didConnect;
- (void) _didNotConnect;
- (void) _willDisconnect;
- (void) _didDisconnect;
- (void) _postError:(NSError *) error;
- (void) _setStatus:(MVChatConnectionStatus) status;

- (void) _addRoomToCache:(NSMutableDictionary *) info;
- (void) _sendRoomListUpdatedNotification;

- (void) _addKnownUser:(MVChatUser *) user;
- (void) _removeKnownUser:(MVChatUser *) user;
- (void) _pruneKnownUsers;

- (void) _addKnownRoom:(MVChatRoom *) room;
- (void) _removeKnownRoom:(MVChatRoom *) room;

- (void) _addJoinedRoom:(MVChatRoom *) room;
- (void) _removeJoinedRoom:(MVChatRoom *) room;

- (NSUInteger) _watchRulesMatchingUser:(MVChatUser *) user;
- (void) _markUserAsOnline:(MVChatUser *) user;
- (void) _markUserAsOffline:(MVChatUser *) user;
@end

NS_ASSUME_NONNULL_END
