#import "UIWindowAdditions.h"

@implementation UIWindow (Additions)
- (BOOL) isFullscreen {
	return self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular;
}
@end
