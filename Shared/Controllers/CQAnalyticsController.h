NS_ASSUME_NONNULL_BEGIN

@interface CQAnalyticsController : NSObject {
	NSMutableDictionary *_data;
	BOOL _pendingSynchronize;
}
+ (CQAnalyticsController *) defaultController;

@property (nonatomic, readonly) NSString *uniqueIdentifier;

- (__nullable id) objectForKey:(NSString *) key;
- (void) setObject:(__nullable id) object forKey:(NSString *) key;

- (void) synchronizeSoon;
- (void) synchronize;
- (void) synchronizeSynchronously;
@end

NS_ASSUME_NONNULL_END
