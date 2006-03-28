@class MVChatUser;
@class AGRegex;

extern NSString *MVChatUserWatchRuleMatchedNotification;

@interface MVChatUserWatchRule : NSObject {
	NSMutableSet *_matchedChatUsers;
	NSString *_nickname;
	AGRegex *_nicknameRegex;
	NSString *_realName;
	AGRegex *_realNameRegex;
	NSString *_username;
	AGRegex *_usernameRegex;
	NSString *_address;
	AGRegex *_addressRegex;
	NSData *_publicKey;
	NSString *_fingerprint;
}
- (BOOL) matchChatUser:(MVChatUser *) user;

- (NSSet *) matchedChatUsers;

- (NSString *) nickname;
- (void) setNickname:(NSString *) nickname;

- (NSString *) realName;
- (void) setRealName:(NSString *) realName;

- (NSString *) username;
- (void) setUsername:(NSString *) username;

- (NSString *) address;
- (void) setAddress:(NSString *) address;

- (NSData *) publicKey;
- (void) setPublicKey:(NSData *) publicKey;

- (NSString *) fingerprint;
- (void) setFingerprint:(NSString *) fingerprint;
@end
