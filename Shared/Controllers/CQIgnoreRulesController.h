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

- (id) initWithConnection:(MVChatConnection *) connection;

@property (nonatomic, readonly) NSArray *ignoreRules;

- (void) addIgnoreRule:(KAIgnoreRule *) ignoreRule;
- (void) removeIgnoreRuleFromString:(NSString *) ignoreRuleString;

- (BOOL) hasIgnoreRuleForUser:(MVChatUser *) user;
- (BOOL) shouldIgnoreMessage:(id) message fromUser:(MVChatUser *) user inRoom:(MVChatRoom *) room;

- (void) synchronize;
@end
