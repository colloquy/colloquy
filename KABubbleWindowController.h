@interface KABubbleWindowController : NSWindowController {
	id _delegate;
	NSTimer *_animationTimer;
	unsigned int _depth;
	BOOL _autoFadeOut;
	SEL _action;
	id _target;
	id _representedObject;
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

- (id) representedObject;
- (void) setRepresentedObject:(id) object;

- (id) delegate;
- (void) setDelegate:(id) delegate;
@end

@interface NSObject (KABubbleWindowControllerDelegate)
- (void) bubbleWillFadeIn:(KABubbleWindowController *) bubble;
- (void) bubbleDidFadeIn:(KABubbleWindowController *) bubble;

- (void) bubbleWillFadeOut:(KABubbleWindowController *) bubble;
- (void) bubbleDidFadeOut:(KABubbleWindowController *) bubble;
@end
