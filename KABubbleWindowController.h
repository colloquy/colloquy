#import <AppKit/NSWindowController.h>

@class NSTimer;

@interface KABubbleWindowController : NSWindowController {
	NSTimer *_animationTimer;
	unsigned int _depth;
}
+ (KABubbleWindowController *) bubble;
+ (KABubbleWindowController *) bubbleWithTitle:(NSString *) title text:(id) text icon:(NSImage *) icon;

- (void) startFadeIn;
- (void) startFadeOut;
@end
