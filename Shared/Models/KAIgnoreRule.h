@class MVChatUser;
@class CQChatController;

#if TARGET_OS_OSX
@protocol JVChatViewController;
#endif

typedef NS_ENUM(OSType, JVIgnoreMatchResult) {
	JVUserIgnored = 'usIg',
	JVMessageIgnored = 'msIg',
	JVNotIgnored = 'noIg'
};

COLLOQUY_EXPORT
@interface KAIgnoreRule : NSObject
+ (instancetype) ruleForUser:(NSString *) user mask:(NSString *) mask message:(NSString *) message inRooms:(NSArray *) rooms isPermanent:(BOOL) permanent friendlyName:(NSString *) friendlyName;
- (instancetype) initForUser:(NSString *) user mask:(NSString *) mask message:(NSString *) message inRooms:(NSArray *) rooms isPermanent:(BOOL) permanent friendlyName:(NSString *) friendlyName;

+ (KAIgnoreRule *) ruleForUser:(NSString *) user message:(NSString *) message inRooms:(NSArray *) rooms isPermanent:(BOOL) permanent friendlyName:(NSString *) friendlyName;
- (instancetype) initForUser:(NSString *) user message:(NSString *) message inRooms:(NSArray *) rooms isPermanent:(BOOL) permanent friendlyName:(NSString *) friendlyName;

#if TARGET_OS_OSX
- (JVIgnoreMatchResult) matchUser:(MVChatUser *) user message:(NSString *) message inView:(id <JVChatViewController>) view;
#else
- (JVIgnoreMatchResult) matchUser:(MVChatUser *) user message:(NSString *) message inTargetRoom:(id) target;
#endif

@property (nonatomic, getter=isPermanent) BOOL permanent;
@property (nonatomic, copy) NSString *friendlyName;
@property (nonatomic, copy) NSArray *rooms;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, copy) NSString *user;
@property (nonatomic, copy) NSString *mask;
@end
