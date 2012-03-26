@interface CQAnalyticsController : NSObject {
	NSMutableDictionary *_data;
	BOOL _pendingSynchronize;
}
+ (CQAnalyticsController *) defaultController;

@property (nonatomic, readonly) NSString *uniqueIdentifier;

- (id) objectForKey:(NSString *) key;
- (void) setObject:(id) object forKey:(NSString *) key;

- (void) synchronizeSoon;
- (void) synchronize;
- (void) synchronizeSynchronously;
@end
