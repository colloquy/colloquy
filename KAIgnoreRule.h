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
}

+ (id) ruleForUser:(NSString *) user message:(NSString *) message inRooms:(NSArray *) rooms usesRegex:(BOOL) regex;
- (id) initForUser:(NSString *) user message:(NSString *) message inRooms:(NSArray *) rooms usesRegex:(BOOL) regex;

- (JVIgnoreMatchResult) matchUser:(NSString *) user message:(NSString *) message inView:(id <JVChatViewController>) view;
@end