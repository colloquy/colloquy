#import <AppKit/NSWindowController.h>

@class NSTimer;

@interface KABubbleWindowController : NSWindowController {
	NSTimer *_animationTimer;
	unsigned int _depth;
}
- (void) startFadeIn;
- (void) startFadeOut;
@end
