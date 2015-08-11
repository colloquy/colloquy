#import "UIViewAdditions.h"

BOOL cq_shouldAnimate(BOOL wantsToAnimate) {
	return wantsToAnimate && !UIAccessibilityIsReduceMotionEnabled();
}


@implementation UIView (Additions)
// reference: http://stackoverflow.com/a/19817135/162361
- (void) cq_addMatchingConstraintsToView:(UIView *) destination
{
	for (NSLayoutConstraint *constraint in [destination.superview.constraints copy]) {
		id first, newFirst = constraint.firstItem;
		id second, newSecond = constraint.secondItem;

		BOOL match = NO;
		if (first == destination) {
			newFirst = self;
			match = YES;
		}
		if (second == destination) {
			newSecond = self;
			match = YES;
		}
		if (first == self) {
			newFirst = destination;
			match = YES;
		}
		if (second == self) {
			newSecond = destination;
			match = YES;
		}

		if (match && newFirst) {
			[destination.superview removeConstraint:constraint];

			@try {
				NSLayoutConstraint *newConstraint = [NSLayoutConstraint constraintWithItem:newFirst attribute:constraint.firstAttribute relatedBy:constraint.relation toItem:newSecond attribute:constraint.secondAttribute multiplier:constraint.multiplier constant:constraint.constant];
				newConstraint.priority = UILayoutPriorityRequired;
				[destination.superview addConstraint:newConstraint];
			} @catch (__unused NSException *e) { }
		}
	}

	for (NSLayoutConstraint *constraint in [self.constraints copy]) {
		if ([constraint class] == [NSLayoutConstraint class] && constraint.firstItem == self) {
			NSLayoutConstraint *newConstraint = [NSLayoutConstraint constraintWithItem:destination attribute:constraint.firstAttribute relatedBy:constraint.relation toItem:constraint.secondItem attribute:constraint.secondAttribute multiplier:constraint.multiplier constant:constraint.constant];
			[destination addConstraint:newConstraint];
			[self removeConstraint:constraint];
		}
	}

	for (NSLayoutConstraint *constraint in [destination.constraints copy]) {
		if ([constraint class] == [NSLayoutConstraint class] && constraint.firstItem == destination) {
			NSLayoutConstraint *newConstraint = [NSLayoutConstraint constraintWithItem:self attribute:constraint.firstAttribute relatedBy:constraint.relation toItem:constraint.secondItem attribute:constraint.secondAttribute multiplier:constraint.multiplier constant:constraint.constant];
			[self addConstraint:newConstraint];
			[destination removeConstraint:constraint];
		}
	}

	self.frame = CGRectIntegral(destination.frame);
	destination.frame = CGRectIntegral(self.frame);
}

@end
