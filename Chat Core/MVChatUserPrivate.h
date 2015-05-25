#import "MVChatUser.h"

NS_ASSUME_NONNULL_BEGIN

@interface MVChatUser (MVChatUserPrivate)
- (void) _connectionDestroyed;
- (void) _setType:(MVChatUserType) type;
- (void) _setUniqueIdentifier:(id) identifier;
- (void) _setNickname:(NSString *) name;
- (void) _setRealName:(NSString * __nullable) name;
- (void) _setUsername:(NSString * __nullable) name;
- (void) _setAccount:(NSString * __nullable) account;
- (void) _setAddress:(NSString * __nullable) address;
- (void) _setServerAddress:(NSString *) address;
- (void) _setPublicKey:(NSData *) key;
- (void) _setFingerprint:(NSString *) fingerprint;
- (void) _setServerOperator:(BOOL) operator;
- (void) _setIdentified:(BOOL) identified;
- (void) _setIdleTime:(NSTimeInterval) time;
- (void) _setStatus:(MVChatUserStatus) status;
- (void) _setDateConnected:(NSDate * __nullable) date;
- (void) _setDateDisconnected:(NSDate * __nullable) date;
- (void) _setDateUpdated:(NSDate *) date;
- (void) _setAwayStatusMessage:(NSData * __nullable) awayStatusMessage;
- (BOOL) _onlineNotificationSent;
- (void) _setOnlineNotificationSent:(BOOL) sent;
@end

NS_ASSUME_NONNULL_END
