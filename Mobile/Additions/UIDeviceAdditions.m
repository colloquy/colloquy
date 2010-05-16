#import "UIDeviceAdditions.h"

#import "NSStringAdditions.h"

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
