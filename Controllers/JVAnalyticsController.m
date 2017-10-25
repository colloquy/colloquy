#import "JVAnalyticsController.h"

#include <sys/sysctl.h>

#include <IOKit/IOKitLib.h>
#include <IOKit/network/IOEthernetInterface.h>
#include <IOKit/network/IONetworkInterface.h>
#include <IOKit/network/IOEthernetController.h>

static NSString *analyticsURL = @"http://colloquy.info/analytics.php";

@implementation JVAnalyticsController
+ (JVAnalyticsController *) defaultController {
	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"JVAllowAnalytics"])
		return nil;

	static BOOL creatingSharedInstance = NO;
	static JVAnalyticsController *sharedInstance = nil;

	if (!sharedInstance && !creatingSharedInstance) {
		creatingSharedInstance = YES;
		sharedInstance = [[self alloc] init];
	}

	return sharedInstance;
}

#pragma mark -

static NSString *hardwareInfoAsString(const char *keyPath) {
	char buffer[512] = { 0 };
	size_t size = sizeof(buffer);
	if (sysctlbyname(keyPath, buffer, &size, NULL, 0) == 0) {
		NSData *bufferData = [[NSData alloc] initWithBytes:buffer length:(size - 1)]; // Trim off the last character which is \0.
		NSString *result = [[NSString alloc] initWithData:bufferData encoding:NSASCIIStringEncoding];
		return result;
	}

	return @"";
}

static int hardwareInfoAsNumber(const char *keyPath) {
	int result = 0;
	size_t size = sizeof(result);
	if (sysctlbyname(keyPath, &result, &size, NULL, 0) == 0)
		return result;
	return 0;
}

static long long hardwareInfoAsLargeNumber(const char *keyPath) {
	long long result = 0;
	size_t size = sizeof(result);
	if (sysctlbyname(keyPath, &result, &size, NULL, 0) == 0)
		return result;
	return 0;
}

static NSString *uniqueMachineIdentifier;

static kern_return_t findEthernetInterfaces(io_iterator_t *matchingServices) {
	NSMutableDictionary *matchingDict = CFBridgingRelease(IOServiceMatching(kIOEthernetInterfaceClass));
	if (!matchingDict)
		return KERN_FAILURE;

	NSMutableDictionary *propertyMatchDict = [[NSMutableDictionary alloc] initWithCapacity:1];
	if (!propertyMatchDict) {
		return KERN_FAILURE;
	}

	propertyMatchDict[@kIOPrimaryInterface] = @YES;
	matchingDict[@kIOPropertyMatchKey] = propertyMatchDict;

	return IOServiceGetMatchingServices(kIOMasterPortDefault, CFBridgingRetain(matchingDict), matchingServices);
}

static kern_return_t getMACAddress(io_iterator_t intfIterator, UInt8 *MACAddress, UInt8 bufferSize) {
	io_object_t intfService;
	io_object_t controllerService;
	kern_return_t kernResult = KERN_FAILURE;

	if (bufferSize < kIOEthernetAddressSize)
		return KERN_FAILURE;

	bzero(MACAddress, bufferSize);

	while ((intfService = IOIteratorNext(intfIterator))) {
		kernResult = IORegistryEntryGetParentEntry(intfService, kIOServicePlane, &controllerService);

		if (kernResult == KERN_SUCCESS) {
			CFTypeRef MACAddressAsCFData = IORegistryEntryCreateCFProperty(controllerService, CFSTR(kIOMACAddress), kCFAllocatorDefault, 0);
			if (MACAddressAsCFData) {
				CFDataGetBytes(MACAddressAsCFData, CFRangeMake(0, kIOEthernetAddressSize), MACAddress);
				CFRelease(MACAddressAsCFData);
			}

			IOObjectRelease(controllerService);
		}

		IOObjectRelease(intfService);
	}

	return kernResult;
}

static void generateUniqueMachineIdentifier() {
	if (uniqueMachineIdentifier)
		return;

	kern_return_t kernResult = KERN_SUCCESS;
	io_iterator_t intfIterator = 0;
	UInt8 MACAddress[kIOEthernetAddressSize];

	kernResult = findEthernetInterfaces(&intfIterator);

	if (kernResult == KERN_SUCCESS) {
		kernResult = getMACAddress(intfIterator, MACAddress, sizeof(MACAddress));
		if (kernResult == KERN_SUCCESS)
			uniqueMachineIdentifier = [[NSString alloc] initWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x", MACAddress[0], MACAddress[1], MACAddress[2], MACAddress[3], MACAddress[4], MACAddress[5]];
	}

	IOObjectRelease(intfIterator);

	if (uniqueMachineIdentifier)
		return;

	uniqueMachineIdentifier = [[[NSUserDefaults standardUserDefaults] stringForKey:@"JVUniqueMachineIdentifier"] copy];
	if (uniqueMachineIdentifier)
		return;

	uniqueMachineIdentifier = [[[NSProcessInfo processInfo] globallyUniqueString] copy];
	[[NSUserDefaults standardUserDefaults] setObject:uniqueMachineIdentifier forKey:@"JVUniqueMachineIdentifier"];
}

- (instancetype) init {
	if (!(self = [super init]))
		return nil;

	generateUniqueMachineIdentifier();

	NSDictionary *systemVersion = [[NSDictionary alloc] initWithContentsOfFile:@"/System/Library/CoreServices/ServerVersion.plist"];
	if ( !systemVersion ) systemVersion = [[NSDictionary alloc] initWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];

	_data = [[NSMutableDictionary alloc] initWithCapacity:10];

	_data[@"machine-model"] = hardwareInfoAsString("hw.model");

#if __ppc__
	_data[@"machine-class"] = @"ppc";
#elif __i386__ || __x86_64__
	_data[@"machine-class"] = @"i386";
#elif __arm__
	_data[@"machine-class"] = @"arm";
#else
	_data[@"machine-class"] = @"unknown";
#endif

	_data[@"machine-cpu-count"] = @(hardwareInfoAsNumber("hw.ncpu"));
	_data[@"machine-cpu-frequency"] = @(hardwareInfoAsLargeNumber("hw.cpufrequency") / 1000000);
	_data[@"machine-memory"] = @(hardwareInfoAsLargeNumber("hw.memsize") / 1024 / 1024);
	_data[@"machine-cpu-64bit"] = (hardwareInfoAsNumber("hw.cpu64bit_capable") ? @"yes" : @"no");
	_data[@"machine-system-name"] = systemVersion[@"ProductName"];
	_data[@"machine-system-version"] = systemVersion[@"ProductVersion"];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate) name:NSApplicationWillTerminateNotification object:nil];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -

- (id) objectForKey:(NSString *) key {
	return _data[key];
}

- (void) setObject:(id) object forKey:(NSString *) key {
	if (object) {
		_data[key] = object;
		[self synchronizeSoon];
	} else [_data removeObjectForKey:key];
}

#pragma mark -

- (NSData *) _requestBody {
	NSMutableString *resultString = [[NSMutableString alloc] initWithCapacity:1024];

	for( __strong NSString *key in _data ) {
		NSString *value = [_data[key] description];

		key = [key stringByEncodingIllegalURLCharacters];
		value = [value stringByEncodingIllegalURLCharacters];

		if (resultString.length)
			[resultString appendString:@"&"];
		[resultString appendFormat:@"%@=%@", key, value];
	}

	NSData *resultData = [resultString dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];

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

	_data[@"machine-identifier"] = uniqueMachineIdentifier;

	[NSURLConnection connectionWithRequest:[self _urlRequest] delegate:nil];

	[_data removeAllObjects];
}

- (void) synchronizeSynchronously {
	if (!_data.count)
		return;

	_pendingSynchronize = NO;
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:_cmd object:nil];

	_data[@"machine-identifier"] = uniqueMachineIdentifier;

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
