#import <Foundation/Foundation.h>

@class JVChatController;
@class AGRegex;

typedef enum _JVIgnoreMatch {
	JVUserMessageIgnored,
	JVMessageIgnored,
	JVNotIgnored
} JVIgnoreMatchResult;

@interface KAInternalIgnoreRule : NSObject {
	NSString *_ignoredUser;
	NSString *_ignoredMessage;
	AGRegex *_userRegex;
	AGRegex *_messageRegex;
	NSArray *_inChannels;
}

+ (id) ruleForUser:(NSString *) user message:(NSString *) message inRooms:(NSArray *) rooms usesRegex:(BOOL) regex;
- (id) initForUser:(NSString *) user message:(NSString *) message inRooms:(NSArray *) rooms usesRegex:(BOOL) regex;

- (JVIgnoreMatchResult) matchesUser:(NSString *) user message:(NSString *) message inChannel:(NSString *) channel;
@end