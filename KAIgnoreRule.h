#import <Foundation/Foundation.h>

@class JVChatController;
@class AGRegex;

@protocol JVChatViewController;

typedef enum _JVIgnoreMatchResult {
	JVUserIgnored,
	JVMessageIgnored,
	JVNotIgnored
} JVIgnoreMatchResult;

@interface KAIgnoreRule : NSObject {
	NSString *_ignoredUser;
	NSString *_ignoredMessage;
	AGRegex *_userRegex;
	AGRegex *_messageRegex;
	NSArray *_inRooms;
	BOOL _permanent;
}
+ (id) ruleForUser:(NSString *) user message:(NSString *) message inRooms:(NSArray *) rooms isPermanent:(BOOL) permanent;
- (id) initForUser:(NSString *) user message:(NSString *) message inRooms:(NSArray *) rooms isPermanent:(BOOL) permanent;

- (JVIgnoreMatchResult) matchUser:(NSString *) user message:(NSString *) message inView:(id <JVChatViewController>) view;
@end