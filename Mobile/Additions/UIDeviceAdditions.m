#import "UIDeviceAdditions.h"

#include <sys/sysctl.h>

#if !TARGET_IPHONE_SIMULATOR
static NSString *hardwareInfoAsString(const char *keyPath) {
	char buffer[512] = { 0 };
	size_t size = sizeof(buffer);
	if (sysctlbyname(keyPath, buffer, &size, NULL, 0) == 0) {
		NSData *bufferData = [[NSData alloc] initWithBytes:buffer length:(size - 1)]; // Trim off the last character which is \0.
		NSString *result = [[NSString alloc] initWithData:bufferData encoding:NSASCIIStringEncoding];
		[bufferData release];
		return [result autorelease];
	}

	return @"";
}
#endif

@implementation UIDevice (UIDeviceColloquyAdditions)
#if TARGET_IPHONE_SIMULATOR
- (NSString *) model {
	// This is needed becuase the real UIDevice.model always returns iPhone Simulator, even for the iPad.
	return [self isPadModel] ? @"iPad Simulator" : @"iPhone Simulator";
}

- (NSString *) localizedModel {
	return self.model;
}
#endif

- (NSString *) modelIdentifier {
#if TARGET_IPHONE_SIMULATOR
	return [self isPadModel] ? @"iPadSimulator1,1" : @"iPhoneSimulator1,1";
#else
	return hardwareInfoAsString("hw.model");
#endif
}

- (BOOL) isSystemFour {
	static BOOL result;
	static BOOL cached;

	if (cached)
		return result;

	result = ([self.systemVersion doubleValue] >= 4.);
	cached = YES;

	return result;
}

- (BOOL) isSystemFive {
	static BOOL result;
	static BOOL cached;

	if (cached)
		return result;

	result = ([self.systemVersion doubleValue] >= 5.);
	cached = YES;

	return result;
}

- (BOOL) isPhoneModel {
	static BOOL result;
	static BOOL cached;

	if (cached)
		return result;

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_3_2
	if ([self respondsToSelector:@selector(userInterfaceIdiom)])
		result = (self.userInterfaceIdiom == UIUserInterfaceIdiomPhone) && [self.model hasCaseInsensitiveSubstring:@"Phone"];
	else
#endif
		result = [self.model hasCaseInsensitiveSubstring:@"Phone"];

	cached = YES;

	return result;
}

- (BOOL) isPodModel {
	static BOOL result;
	static BOOL cached;

	if (cached)
		return result;

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_3_2
	if ([self respondsToSelector:@selector(userInterfaceIdiom)])
		result = (self.userInterfaceIdiom == UIUserInterfaceIdiomPhone) && [self.model hasCaseInsensitiveSubstring:@"Pod"];
	else
#endif
		result = [self.model hasCaseInsensitiveSubstring:@"Pod"];

	cached = YES;

	return result;
}

- (BOOL) isPadModel {
	static BOOL result;
	static BOOL cached;

	if (cached)
		return result;

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_3_2
	if ([self respondsToSelector:@selector(userInterfaceIdiom)])
		result = (self.userInterfaceIdiom == UIUserInterfaceIdiomPad);
#endif

	cached = YES;

	return result;
}
@end
