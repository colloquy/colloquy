#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface JVAnalyticsController : NSObject {
	NSMutableDictionary *_data;
	BOOL _pendingSynchronize;
}
#if __has_feature(objc_class_property)
@property (readonly, strong, class) JVAnalyticsController *defaultController;
#else
+ (JVAnalyticsController *) defaultController;
#endif

- (nullable id) objectForKey:(NSString *) key;
- (void) setObject:(nullable id) object forKey:(NSString *) key;

- (void) synchronizeSoon;
- (void) synchronize;
- (void) synchronizeSynchronously;
@end

NS_ASSUME_NONNULL_END
