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
- (void) removeMatchedUser:(MVChatUser *) user;

#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
@property(readonly) NSSet *matchedChatUsers;

@property(bycopy) NSString *nickname;
@property(readonly) BOOL nicknameIsRegularExpression;

@property(bycopy) NSString *realName;
@property(readonly) BOOL realNameIsRegularExpression;

@property(bycopy) NSString *username;
@property(readonly) BOOL usernameIsRegularExpression;

@property(bycopy) NSString *address;
@property(readonly) BOOL addressIsRegularExpression;

@property(ivar, bycopy) NSData *publicKey;

@property(ivar) BOOL interim;

@property(ivar, bycopy) NSArray *applicableServerDomains;

#else

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
#endif

- (BOOL) isInterim;
@end
