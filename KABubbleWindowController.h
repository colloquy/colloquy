#import <AppKit/NSWindowController.h>

@class NSTimer;

@interface KABubbleWindowController : NSWindowController {
	NSTimer *_animationTimer;
	unsigned int _depth;
	BOOL _autoFadeOut;
	SEL _action;
	id _target;
}
+ (KABubbleWindowController *) bubble;
+ (KABubbleWindowController *) bubbleWithTitle:(NSString *) title text:(id) text icon:(NSImage *) icon;

- (void) startFadeIn;
- (void) startFadeOut;

- (BOOL) automaticallyFadesOut;
- (void) setAutomaticallyFadesOut:(BOOL) autoFade;

- (id) target;
- (void) setTarget:(id) object;

- (SEL) action;
- (void) setAction:(SEL) selector;
@end
