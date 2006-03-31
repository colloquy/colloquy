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
- (id) initWithDictionaryRepresentation:(NSDictionary *) dictionary;
- (NSDictionary *) dictionaryRepresentation;

- (BOOL) matchChatUser:(MVChatUser *) user;

- (NSSet *) matchedChatUsers;

- (NSString *) nickname;
- (void) setNickname:(NSString *) nickname;
- (BOOL) nicknameIsRegularExpression;

- (NSString *) realName;
- (void) setRealName:(NSString *) realName;
- (BOOL) realNameIsRegularExpression;

- (NSString *) username;
- (void) setUsername:(NSString *) username;
- (BOOL) usernameIsRegularExpression;

- (NSString *) address;
- (void) setAddress:(NSString *) address;
- (BOOL) addressIsRegularExpression;

- (NSData *) publicKey;
- (void) setPublicKey:(NSData *) publicKey;
@end
