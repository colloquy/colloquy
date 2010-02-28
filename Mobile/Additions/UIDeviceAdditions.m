#import "UIDeviceAdditions.h"

#import "NSStringAdditions.h"

@implementation UIDevice (UIDeviceColloquyAdditions)
#if TARGET_IPHONE_SIMULATOR
- (NSString *) model {
	// This is needed becuase the real UIDevice.model always returns iPhone Simulator, even for the iPad.
	if ([UIScreen mainScreen].bounds.size.width >= 768 || [UIScreen mainScreen].bounds.size.height >= 1024)
		return @"iPad Simulator";
	return @"iPhone Simulator";
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

	if ([self respondsToSelector:@selector(userInterfaceIdiom)])
		result = (self.userInterfaceIdiom == UIUserInterfaceIdiomPhone) && [self.model hasCaseInsensitiveSubstring:@"Phone"];
	else result = [self.model hasCaseInsensitiveSubstring:@"Phone"];

	cached = YES;

	return result;
}

- (BOOL) isPodModel {
	static BOOL result;
	static BOOL cached;

	if (cached)
		return result;

	if ([self respondsToSelector:@selector(userInterfaceIdiom)])
		result = (self.userInterfaceIdiom == UIUserInterfaceIdiomPhone) && [self.model hasCaseInsensitiveSubstring:@"Pod"];
	else result = [self.model hasCaseInsensitiveSubstring:@"Pod"];

	cached = YES;

	return result;
}

- (BOOL) isPadModel {
	static BOOL result;
	static BOOL cached;

	if (cached)
		return result;

	if ([self respondsToSelector:@selector(userInterfaceIdiom)])
		result = (self.userInterfaceIdiom == UIUserInterfaceIdiomPad);

	cached = YES;

	return result;
}
@end
