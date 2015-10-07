#if defined(__IPHONE_9_1)
#import "CQ3DTouchGestureRecognizer.h"

#import <UIKit/UIGestureRecognizerSubclass.h>

@interface UITouch (CQ3DTouchAdditions)
@end

@implementation UITouch (CQ3DTouchAdditions)
- (BOOL) cq_is3DTouch {
	return ((self.estimatedProperties & UITouchPropertyForce) == UITouchPropertyForce) || ((self.updatedProperties & UITouchPropertyForce) == UITouchPropertyForce);
}
@end

#pragma mark -

@interface CQ3DTouchGestureRecognizer ()
@property BOOL canRecognizeForceTouch;
@end

@implementation CQ3DTouchGestureRecognizer
- (instancetype) init {
	if (!(self = [super init]))
		return nil;

	[self checkForForceTouchRecognitionAvailability];

	return self;
}

- (instancetype) initWithTarget:(id) target action:(SEL) action {
	if (!(self = [super initWithTarget:target action:action]))
		return nil;

	[self checkForForceTouchRecognitionAvailability];

	return self;
}

#pragma mark -

- (void) checkForForceTouchRecognitionAvailability {
	self.canRecognizeForceTouch = [UITouch instancesRespondToSelector:@selector(estimatedProperties)] && [UITouch instancesRespondToSelector:@selector(updatedProperties)];
}

#pragma mark -

- (void) touchesBegan:(NSSet<UITouch *> *) touches withEvent:(UIEvent *) event {
	if (!self.canRecognizeForceTouch)
		return;

	for (UITouch *touch in touches) {
		if (!touch.cq_is3DTouch)
			continue;

		self.state = UIGestureRecognizerStateBegan;
		break;
	}
}

- (void) touchesMoved:(NSSet<UITouch *> *) touches withEvent:(UIEvent *) event {
	if (!self.canRecognizeForceTouch)
		return;

	if (self.state == UIGestureRecognizerStateBegan)
		self.state = UIGestureRecognizerStateChanged;
}

- (void) touchesEnded:(NSSet<UITouch *> *) touches withEvent:(UIEvent *) event {
	if (!self.canRecognizeForceTouch)
		return;

	if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged)
		self.state = UIGestureRecognizerStateEnded;
}

- (void) touchesCancelled:(NSSet<UITouch *> *) touches withEvent:(UIEvent *) event {
	if (!self.canRecognizeForceTouch)
		return;

	if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged)
		self.state = UIGestureRecognizerStateCancelled;

	[self reset];
}
@end
#endif
