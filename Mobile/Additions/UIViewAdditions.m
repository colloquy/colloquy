#import "UIViewAdditions.h"

BOOL cq_shouldAnimate(BOOL wantsToAnimate) {
	return wantsToAnimate && !UIAccessibilityIsReduceMotionEnabled();
}
