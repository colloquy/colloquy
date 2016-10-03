#import <Foundation/NSNotification.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSNotificationCenter (NSNotificationCenterAdditions)
+ (NSNotificationCenter *) chatCenter;
#if __has_feature(objc_class_property)
@property (class, readonly, strong) NSNotificationCenter *chatCenter;
#endif

- (void) postNotificationOnMainThread:(NSNotification *) notification;
- (void) postNotificationOnMainThread:(NSNotification *) notification waitUntilDone:(BOOL) wait;

- (void) postNotificationOnMainThreadWithName:(NSNotificationName) name object:(id __nullable) object;
- (void) postNotificationOnMainThreadWithName:(NSNotificationName) name object:(id __nullable) object userInfo:(NSDictionary * __nullable) userInfo;
- (void) postNotificationOnMainThreadWithName:(NSNotificationName) name object:(id __nullable) object userInfo:(NSDictionary * __nullable) userInfo waitUntilDone:(BOOL) wait;
@end

NS_ASSUME_NONNULL_END
