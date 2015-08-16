#import "UIViewAdditions.h"
#import "UIDeviceAdditions.h"

BOOL cq_shouldAnimate(BOOL wantsToAnimate) {
	if (![UIDevice currentDevice].isSystemEight) {
		return wantsToAnimate;
	}

	return wantsToAnimate && !UIAccessibilityIsReduceMotionEnabled();
}
