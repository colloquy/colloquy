@class JVChatController;
@class AGRegex;

@protocol JVChatViewController;

typedef enum _JVIgnoreMatchResult {
	JVUserIgnored = 'usIg',
	JVMessageIgnored = 'msIg',
	JVNotIgnored = 'noIg'
} JVIgnoreMatchResult;

@interface KAIgnoreRule : NSObject {
	NSString *_ignoredUser;
	NSString *_ignoredMessage;
	AGRegex *_userRegex;
	AGRegex *_messageRegex;
	NSMutableArray *_rooms;
	NSString *_friendlyName;
	BOOL _permanent;
}
+ (id) ruleForUser:(NSString *) user message:(NSString *) message inRooms:(NSArray *) rooms isPermanent:(BOOL) permanent friendlyName:(NSString *)friendlyName;
- (id) initForUser:(NSString *) user message:(NSString *) message inRooms:(NSArray *) rooms isPermanent:(BOOL) permanent friendlyName:(NSString *)friendlyName;

- (JVIgnoreMatchResult) matchUser:(NSString *) user message:(NSString *) message inView:(id <JVChatViewController>) view;

- (BOOL) isPermanent;
- (void) setPermanent:(BOOL) permanent;

- (NSString *) friendlyName;
- (void) setFriendlyName:(NSString *) friendlyName;

- (NSArray *) rooms;
- (void) setRooms:(NSArray *) rooms;

- (NSString *) message;
- (void) setMessage:(NSString *) message;

- (NSString *) user;
- (void) setUser:(NSString *) user;
@end