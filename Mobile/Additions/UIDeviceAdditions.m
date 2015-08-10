#import "UIDeviceAdditions.h"

#if !TARGET_IPHONE_SIMULATOR

#import <sys/sysctl.h>

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

- (BOOL) isPhoneModel {
	static BOOL result;
	static BOOL cached;

	if (cached)
		return result;

	result = (self.userInterfaceIdiom == UIUserInterfaceIdiomPad);
	cached = YES;

	return result;
}

- (BOOL) isPadModel {
	static BOOL result;
	static BOOL cached;

	if (cached)
		return result;

	result = (self.userInterfaceIdiom == UIUserInterfaceIdiomPad);
	cached = YES;

	return result;
}

static BOOL isRetinaResultCached = NO;
- (BOOL) isRetina {
	static BOOL result;

	if (isRetinaResultCached)
		return result;

	result = [UIApplication sharedApplication].keyWindow.screen.scale > 1.;
	isRetinaResultCached = YES;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cq_windowDidBecomeKey:) name:UIWindowDidBecomeKeyNotification object:nil];

	return result;
}

- (void) cq_windowDidBecomeKey:(NSNotification *) notification {
	isRetinaResultCached = NO;
}
@end
