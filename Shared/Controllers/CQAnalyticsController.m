#import "CQAnalyticsController.h"

#include <sys/sysctl.h>

#if SYSTEM(MAC)
#include <IOKit/IOKitLib.h>
#include <IOKit/network/IOEthernetInterface.h>
#include <IOKit/network/IONetworkInterface.h>
#include <IOKit/network/IOEthernetController.h>
#endif

static NSString *applicationNameKey = @"application-name";

#if SYSTEM(IOS)
static NSString *analyticsURL = @"http://colloquy.mobi/analytics.php";
static NSString *deviceIdentifierKey = @"device-identifier";
#elif SYSTEM(MAC)
static NSString *analyticsURL = @"http://colloquy.info/analytics.php";
static NSString *deviceIdentifierKey = @"machine-identifier";
#endif

static NSString *deviceIdentifier;
static NSString *applicationName;

#if SYSTEM(MAC)
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

static kern_return_t findEthernetInterfaces(io_iterator_t *matchingServices) {
	CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOEthernetInterfaceClass);
	if (!matchingDict)
		return KERN_FAILURE;

	CFMutableDictionaryRef propertyMatchDict = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	if (!propertyMatchDict) {
		CFRelease(matchingDict);
		return KERN_FAILURE;
	}

	CFDictionarySetValue(propertyMatchDict, CFSTR(kIOPrimaryInterface), kCFBooleanTrue);
	CFDictionarySetValue(matchingDict, CFSTR(kIOPropertyMatchKey), propertyMatchDict);

	CFRelease(propertyMatchDict);
	propertyMatchDict = NULL;

	return IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, matchingServices);
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
#endif

static void generateDeviceIdentifier() {
	if (deviceIdentifier)
		return;

	deviceIdentifier = [[[NSUserDefaults standardUserDefaults] stringForKey:@"JVUniqueMachineIdentifier"] copy];
	if (deviceIdentifier)
		return;

#if SYSTEM(MAC)
	kern_return_t kernResult = KERN_SUCCESS;
	io_iterator_t intfIterator;
	UInt8 MACAddress[kIOEthernetAddressSize];

	kernResult = findEthernetInterfaces(&intfIterator);

	if (kernResult == KERN_SUCCESS) {
		kernResult = getMACAddress(intfIterator, MACAddress, sizeof(MACAddress));
		if (kernResult == KERN_SUCCESS)
			deviceIdentifier = [[NSString alloc] initWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x", MACAddress[0], MACAddress[1], MACAddress[2], MACAddress[3], MACAddress[4], MACAddress[5]];
	}

	IOObjectRelease(intfIterator);
#elif SYSTEM(IOS)
	deviceIdentifier = [[UIDevice currentDevice].identifierForVendor.UUIDString mutableCopy];
	if (deviceIdentifier)
		return;
#endif

	deviceIdentifier = [[[NSProcessInfo processInfo] globallyUniqueString] copy];

	[[NSUserDefaults standardUserDefaults] setObject:deviceIdentifier forKey:@"JVUniqueMachineIdentifier"];
}

#pragma mark -

@implementation CQAnalyticsController
+ (CQAnalyticsController *) defaultController {
#if SYSTEM(MAC)
	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"JVAllowAnalytics"])
		return nil;
#endif

	static BOOL creatingSharedInstance = NO;
	static CQAnalyticsController *sharedInstance = nil;

	if (!sharedInstance && !creatingSharedInstance) {
		creatingSharedInstance = YES;
		sharedInstance = [[self alloc] init];
	}

	return sharedInstance;
}

#pragma mark -

- (instancetype) init {
	if (!(self = [super init]))
		return nil;

	if (!analyticsURL) {
		return nil;
	}

	_data = [[NSMutableDictionary alloc] initWithCapacity:10];

	generateDeviceIdentifier();

#if SYSTEM(IOS)
	_data[@"device-model"] = [UIDevice currentDevice].modelIdentifier;
	_data[@"device-system-name"] = [UIDevice currentDevice].systemName;
	_data[@"device-system-version"] = [UIDevice currentDevice].systemVersion;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate) name:UIApplicationWillTerminateNotification object:nil];
#elif SYSTEM(MAC)
	NSDictionary *systemVersion = [[NSDictionary alloc] initWithContentsOfFile:@"/System/Library/CoreServices/ServerVersion.plist"];
	if ( !systemVersion ) systemVersion = [[NSDictionary alloc] initWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];

	[_data setObject:hardwareInfoAsString("hw.model") forKey:@"machine-model"];

#if __ppc__
	[_data setObject:@"ppc" forKey:@"machine-class"];
#elif __i386__ || __x86_64__
	[_data setObject:@"i386" forKey:@"machine-class"];
#elif __arm__ || __arm64__
	[_data setObject:@"arm" forKey:@"machine-class"];
#else
	[_data setObject:@"unknown" forKey:@"machine-class"];
#endif

	[_data setObject:[NSNumber numberWithUnsignedInt:hardwareInfoAsNumber("hw.ncpu")] forKey:@"machine-cpu-count"];
	[_data setObject:[NSNumber numberWithUnsignedInt:hardwareInfoAsLargeNumber("hw.cpufrequency") / 1000000] forKey:@"machine-cpu-frequency"];
	[_data setObject:[NSNumber numberWithUnsignedLongLong:hardwareInfoAsLargeNumber("hw.memsize") / 1024 / 1024] forKey:@"machine-memory"];
	[_data setObject:(hardwareInfoAsNumber("hw.cpu64bit_capable") ? @"yes" : @"no") forKey:@"machine-cpu-64bit"];
	[_data setObject:[systemVersion objectForKey:@"ProductName"] forKey:@"machine-system-name"];
	[_data setObject:[systemVersion objectForKey:@"ProductVersion"] forKey:@"machine-system-version"];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate) name:NSApplicationWillTerminateNotification object:nil];
#endif

	if (!applicationName)
		applicationName = [[NSBundle mainBundle].infoDictionary[@"CFBundleName"] copy];

	NSAssert([applicationName isEqualToString:@"Colloquy"], @"If you are not Colloquy, you need to change analyticsURL to a new URL or nil. Thanks!");

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -

- (NSString *) uniqueIdentifier {
	generateDeviceIdentifier();

	return [[NSUserDefaults standardUserDefaults] objectForKey:@"JVUniqueMachineIdentifier"];
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

	for (__strong NSString *key in _data) {
		NSString *value = [_data[key] description];

		key = [key stringByEncodingIllegalURLCharacters];
		value = [value stringByEncodingIllegalURLCharacters];

		if (resultString.length)
			[resultString appendString:@"&"];
		[resultString appendFormat:@"%@=%@", key, value];
	}

	MVAutorelease(resultString);

	return [resultString dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
}

- (NSMutableURLRequest *) _urlRequest {
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:analyticsURL]];

	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:[self _requestBody]];
	[request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
	[request setTimeoutInterval:30.];

	return MVAutorelease(request);
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

	_data[deviceIdentifierKey] = deviceIdentifier;
	_data[applicationNameKey] = applicationName;

	[NSURLConnection connectionWithRequest:[self _urlRequest] delegate:nil];

	[_data removeAllObjects];
}

- (void) synchronizeSynchronously {
	if (!_data.count)
		return;

	_pendingSynchronize = NO;
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:_cmd object:nil];

	_data[deviceIdentifierKey] = deviceIdentifier;
	_data[applicationNameKey] = applicationName;

	NSMutableURLRequest *request = [self _urlRequest];
	[request setTimeoutInterval:5.];

	[NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:NULL];

	[_data removeAllObjects];
}

#pragma mark -

- (void) applicationWillTerminate {
	[self synchronizeSynchronously];
}
@end
