#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class MVChatUser;
@class CQChatController;

#if SYSTEM(MAC)
@protocol JVChatViewController;
#endif

typedef NS_ENUM(OSType, JVIgnoreMatchResult) {
	JVUserIgnored = 'usIg',
	JVMessageIgnored = 'msIg',
	JVNotIgnored = 'noIg'
};

@interface KAIgnoreRule : NSObject
+ (instancetype) ruleForUser:(nullable NSString *) user mask:(nullable NSString *) mask message:(nullable NSString *) message inRooms:(nullable NSArray<NSString*> *) rooms isPermanent:(BOOL) permanent friendlyName:(nullable NSString *) friendlyName;
- (instancetype) initForUser:(nullable NSString *) user mask:(nullable NSString *) mask message:(nullable NSString *) message inRooms:(nullable NSArray<NSString*> *) rooms isPermanent:(BOOL) permanent friendlyName:(nullable NSString *) friendlyName;

+ (instancetype) ruleForUser:(nullable NSString *) user message:(nullable NSString *) message inRooms:(nullable NSArray<NSString*> *) rooms isPermanent:(BOOL) permanent friendlyName:(nullable NSString *) friendlyName;
- (instancetype) initForUser:(nullable NSString *) user message:(nullable NSString *) message inRooms:(nullable NSArray<NSString*> *) rooms isPermanent:(BOOL) permanent friendlyName:(nullable NSString *) friendlyName;

#if SYSTEM(MAC)
- (JVIgnoreMatchResult) matchUser:(MVChatUser *) user message:(nullable NSString *) message inView:(nullable id <JVChatViewController>) view;
#else
- (JVIgnoreMatchResult) matchUser:(MVChatUser *) user message:(NSString *) message inTargetRoom:(id) target;
#endif

@property (nonatomic, getter=isPermanent) BOOL permanent;
@property (nonatomic, copy) NSString *friendlyName;
@property (nonatomic, copy, nullable) NSArray<NSString*> *rooms;
@property (nonatomic, copy, nullable) NSString *message;
@property (nonatomic, copy, nullable) NSString *user;
@property (nonatomic, copy, nullable) NSString *mask;
@end

NS_ASSUME_NONNULL_END
