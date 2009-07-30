@interface CQAnalyticsController : NSObject {
	NSMutableDictionary *_data;
}
+ (CQAnalyticsController *) defaultController;

- (id) objectForKey:(NSString *) key;
- (void) setObject:(id) object forKey:(NSString *) key;

- (void) synchronize;
- (void) synchronizeSynchronously;
@end
