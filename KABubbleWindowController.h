/* KABubbleWindowController */

#import <Cocoa/Cocoa.h>

@interface KABubbleWindowController : NSWindowController {
	NSTimer *animationTimer;
}

- (void) fadeIn:(NSTimer *) inTimer;
- (void) fadeOut:(NSTimer *) inTimer;
- (void) stopTimer;

@end
