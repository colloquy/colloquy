@class KAIgnoreRule;
@class MVChatConnection;
@class MVChatUser;
@class MVChatRoom;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const CQIgnoreRulesNotSavedNotification;

@interface CQIgnoreRulesController : NSObject
- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithConnection:(MVChatConnection *) connection NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) NSArray <KAIgnoreRule *> *ignoreRules;

- (void) addIgnoreRule:(KAIgnoreRule *) ignoreRule;
- (void) removeIgnoreRule:(KAIgnoreRule *) ignoreRule;
- (void) removeIgnoreRuleFromString:(NSString *) ignoreRuleString;

- (BOOL) hasIgnoreRuleForUser:(MVChatUser *) user;
- (BOOL) shouldIgnoreMessage:(id) message fromUser:(MVChatUser *) user inRoom:(MVChatRoom *) room;

- (void) synchronize;
@end

NS_ASSUME_NONNULL_END
