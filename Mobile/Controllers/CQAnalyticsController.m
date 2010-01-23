#import "CQAnalyticsController.h"

#import "NSStringAdditions.h"

static NSString *analyticsURL = @"http://colloquy.mobi/analytics.php";
static NSString *deviceIdentifier;
static NSString *applicationName;

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

	if (!analyticsURL) {
		[self release];
		return nil;
	}

	_data = [[NSMutableDictionary alloc] initWithCapacity:10];

	[_data setObject:[[UIDevice currentDevice] model] forKey:@"device-model"];
	[_data setObject:[[UIDevice currentDevice] systemName] forKey:@"device-system-name"];
	[_data setObject:[[UIDevice currentDevice] systemVersion] forKey:@"device-system-version"];

	if (!applicationName)
		applicationName = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"] copy];

	if (!deviceIdentifier)
		deviceIdentifier = [[[UIDevice currentDevice] uniqueIdentifier] copy];

	NSAssert([applicationName isEqualToString:@"Colloquy"], @"If you are not Colloquy, you need to change analyticsURL to a new URL or nil. Thanks!");

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
	if (object) {
		[_data setObject:object forKey:key];
		[self synchronizeSoon];
	} else [_data removeObjectForKey:key];
}

#pragma mark -

- (NSData *) _requestBody {
	NSMutableString *resultString = [[NSMutableString alloc] initWithCapacity:1024];

	for (NSString *key in _data) {
		NSString *value = [[_data objectForKey:key] description];

		key = [key stringByEncodingIllegalURLCharacters];
		value = [value stringByEncodingIllegalURLCharacters];

		if (resultString.length)
			[resultString appendString:@"&"];
		[resultString appendFormat:@"%@=%@", key, value];
	}

	NSData *resultData = [resultString dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
	[resultString release];

	return resultData;
}

- (NSMutableURLRequest *) _urlRequest {
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:analyticsURL]];

	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:[self _requestBody]];
	[request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
	[request setTimeoutInterval:30.];

	return request;
}

#pragma mark -

- (void) synchronizeSoon {
	if (_pendingSynchronize)
		return;
	[self performSelector:@selector(synchronize) withObject:nil afterDelay:10.];
}

- (void) synchronize {
	if (!_data.count)
		return;

	_pendingSynchronize = NO;
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:_cmd object:nil];

	[_data setObject:deviceIdentifier forKey:@"device-identifier"];
	[_data setObject:applicationName forKey:@"application-name"];

	[NSURLConnection connectionWithRequest:[self _urlRequest] delegate:nil];

	[_data removeAllObjects];
}

- (void) synchronizeSynchronously {
	if (!_data.count)
		return;

	_pendingSynchronize = NO;
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:_cmd object:nil];

	[_data setObject:deviceIdentifier forKey:@"device-identifier"];
	[_data setObject:applicationName forKey:@"application-name"];

	NSMutableURLRequest *request = [self _urlRequest];
	[request setTimeoutInterval:15.];

	[NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:NULL];

	[_data removeAllObjects];
}

#pragma mark -

- (void) applicationWillTerminate {
	[self synchronizeSynchronously];
}
@end
