#import "MVChatUser.h"

@interface MVChatUser (MVChatUserPrivate)
- (void) _setUniqueIdentifier:(id) identifier;
- (void) _setNickname:(NSString *) name;
- (void) _setRealName:(NSString *) name;
- (void) _setUsername:(NSString *) name;
- (void) _setAddress:(NSString *) address;
- (void) _setServerAddress:(NSString *) address;
- (void) _setPublicKey:(NSData *) key;
- (void) _setFingerprint:(NSString *) fingerprint;
- (void) _setServerOperator:(BOOL) operator;
- (void) _setIdentified:(BOOL) identified;
- (void) _setWatched:(BOOL) watched;
- (void) _setIdleTime:(NSTimeInterval) time;
- (void) _setStatus:(MVChatUserStatus) status;
- (void) _setDateConnected:(NSDate *) date;
- (void) _setDateDisconnected:(NSDate *) date;
- (void) _setDateUpdated:(NSDate *) date;
- (void) _setAwayStatusMessage:(NSData *) awayStatusMessage;
- (BOOL) _onlineNotificationSent;
- (void) _setOnlineNotificationSent:(BOOL) sent;
@end