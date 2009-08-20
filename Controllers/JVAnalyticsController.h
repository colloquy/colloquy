@interface JVAnalyticsController : NSObject {
	NSMutableDictionary *_data;
	BOOL _pendingSynchronize;
}
+ (JVAnalyticsController *) defaultController;

- (id) objectForKey:(NSString *) key;
- (void) setObject:(id) object forKey:(NSString *) key;

- (void) synchronizeSoon;
- (void) synchronize;
- (void) synchronizeSynchronously;
@end
