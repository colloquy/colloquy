@class MVChatUser;
@class AGRegex;

extern NSString *MVChatUserWatchRuleMatchedNotification;

@interface MVChatUserWatchRule : NSObject <NSCopying> {
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
	NSArray *_applicableServerDomains;
	BOOL _interim;
}
- (id) initWithDictionaryRepresentation:(NSDictionary *) dictionary;
- (NSDictionary *) dictionaryRepresentation;

- (BOOL) isEqualToChatUserWatchRule:(MVChatUserWatchRule *) anotherRule;

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

- (BOOL) isInterim;
- (void) setInterim:(BOOL) interim;

- (NSArray *) applicableServerDomains;
- (void) setApplicableServerDomains:(NSArray *) serverDomains;
@end
