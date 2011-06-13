#import <ChatCore/MVChatConnection.h>

#if SYSTEM(IOS)
@class CQBouncerSettings;
#endif

@interface MVChatConnection (MVChatConnectionAdditions)
+ (NSString *) defaultNickname;
+ (NSString *) defaultUsernameWithNickname:(NSString *) nickname;
+ (NSString *) defaultRealName;
+ (NSString *) defaultQuitMessage;
+ (NSStringEncoding) defaultEncoding;

@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSArray *automaticJoinedRooms;
@property (nonatomic, copy) NSArray *automaticCommands;
@property (nonatomic) BOOL automaticallyConnect;

- (void) savePasswordsToKeychain;
- (void) loadPasswordsFromKeychain;

#if SYSTEM(IOS)
@property (nonatomic) BOOL multitaskingSupported;
@property (nonatomic) BOOL pushNotificationsEnabled;
@property (nonatomic, readonly, getter = isDirectConnection) BOOL directConnection;
@property (nonatomic, getter = isTemporaryDirectConnection) BOOL temporaryDirectConnection;
@property (nonatomic, copy) NSString *bouncerIdentifier;
@property (nonatomic, copy) CQBouncerSettings *bouncerSettings;

- (void) connectDirectly;
- (void) connectAppropriately;

- (void) sendPushNotificationCommands;
#endif
@end
