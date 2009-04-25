@class MVChatUser;
@class MVChatConnection;

extern NSString *MVChatUserWatchRuleMatchedNotification;
extern NSString *MVChatUserWatchRuleRemovedMatchedUserNotification;

@interface MVChatUserWatchRule : NSObject <NSCopying> {
	NSMutableSet *_matchedChatUsers;
	NSString *_nickname;
	NSString *_realName;
	NSString *_username;
	NSString *_address;
	NSData *_publicKey;
	NSArray *_applicableServerDomains;
	BOOL _nicknameIsRegex;
	BOOL _realNameIsRegex;
	BOOL _usernameIsRegex;
	BOOL _addressIsRegex;
	BOOL _interim;
}
- (id) initWithDictionaryRepresentation:(NSDictionary *) dictionary;
- (NSDictionary *) dictionaryRepresentation;

- (BOOL) isEqualToChatUserWatchRule:(MVChatUserWatchRule *) anotherRule;

- (BOOL) matchChatUser:(MVChatUser *) user;
- (void) removeMatchedUser:(MVChatUser *) user;
- (void) removeMatchedUsersForConnection:(MVChatConnection *) connection;

#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
@property(readonly) NSSet *matchedChatUsers;

@property(copy) NSString *nickname;
@property(readonly) BOOL nicknameIsRegularExpression;

@property(copy) NSString *realName;
@property(readonly) BOOL realNameIsRegularExpression;

@property(copy) NSString *username;
@property(readonly) BOOL usernameIsRegularExpression;

@property(copy) NSString *address;
@property(readonly) BOOL addressIsRegularExpression;

@property(copy) NSData *publicKey;

@property(getter=isInterim) BOOL interim;

@property(copy) NSArray *applicableServerDomains;

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
