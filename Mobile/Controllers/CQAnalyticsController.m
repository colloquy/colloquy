#import "CQAnalyticsController.h"

@implementation CQAnalyticsController
+ (CQAnalyticsController *) defaultController {
	static BOOL creatingSharedInstance = NO;
	static CQAnalyticsController *sharedInstance = nil;

	if (!sharedInstance && !creatingSharedInstance) {
		creatingSharedInstance = YES;
		sharedInstance = [[self alloc] init];
	}

	return sharedInstance;
}

#pragma mark -

- (id) init {
	if (!(self = [super init]))
		return nil;

	_data = [[NSMutableDictionary alloc] initWithCapacity:10];

	[_data setObject:[[UIDevice currentDevice] model] forKey:@"device-model"];
	[_data setObject:[[UIDevice currentDevice] systemName] forKey:@"device-system-name"];
	[_data setObject:[[UIDevice currentDevice] systemVersion] forKey:@"device-system-version"];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate) name:UIApplicationWillTerminateNotification object:nil];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_data release];

	[super dealloc];
}

#pragma mark -

- (id) objectForKey:(NSString *) key {
	return [_data objectForKey:key];
}

- (void) setObject:(id) object forKey:(NSString *) key {
	if (object) [_data setObject:object forKey:key];
	else [_data removeObjectForKey:key];
}

#pragma mark -

- (void) synchronize {
	if (!_data.count)
		return;

	[_data setObject:[[UIDevice currentDevice] uniqueIdentifier] forKey:@"device-identifier"];

	NSLog(@"sync %@", [_data description]);

	[_data removeAllObjects];
}

- (void) synchronizeSynchronously {
	if (!_data.count)
		return;

	[_data setObject:[[UIDevice currentDevice] uniqueIdentifier] forKey:@"device-identifier"];

	NSLog(@"sync %@", [_data description]);

	[_data removeAllObjects];
}

#pragma mark -

- (void) applicationWillTerminate {
	[self synchronizeSynchronously];
}
@end
