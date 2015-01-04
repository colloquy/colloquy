@class KAIgnoreRule;
@class MVChatConnection;
@class MVChatString;
@class MVChatUser;
@class MVChatRoom;

extern NSString *const CQIgnoreRulesNotSavedNotification;

@interface CQIgnoreRulesController : NSObject {
	NSMutableArray *_ignoreRules;
	MVChatConnection *_connection;

	NSString *_appSupportPath;
}

- (instancetype) initWithConnection:(MVChatConnection *) connection NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) NSArray *ignoreRules;

- (void) addIgnoreRule:(KAIgnoreRule *) ignoreRule;
- (void) removeIgnoreRule:(KAIgnoreRule *) ignoreRule;
- (void) removeIgnoreRuleFromString:(NSString *) ignoreRuleString;

- (BOOL) hasIgnoreRuleForUser:(MVChatUser *) user;
- (BOOL) shouldIgnoreMessage:(id) message fromUser:(MVChatUser *) user inRoom:(MVChatRoom *) room;

- (void) synchronize;
@end
