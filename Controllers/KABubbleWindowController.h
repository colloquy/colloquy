#import <Cocoa/Cocoa.h>

@protocol KABubbleWindowControllerDelegate;

@interface KABubbleWindowController : NSWindowController <NSWindowDelegate> {
	id _self;
	NSTimer *_animationTimer;
	NSUInteger _depth;
	BOOL _autoFadeOut;
	SEL _action;
	id _representedObject;
}
+ (KABubbleWindowController *) bubble;
+ (KABubbleWindowController *) bubbleWithTitle:(NSString *) title text:(id) text icon:(NSImage *) icon;

- (void) startFadeIn;
- (void) startFadeOut;

@property BOOL automaticallyFadesOut;
@property (weak) id target;
@property SEL action;
@property (strong) id representedObject;
@property (weak) id<KABubbleWindowControllerDelegate> delegate;
@end

@protocol KABubbleWindowControllerDelegate <NSObject>
@optional
- (void) bubbleWillFadeIn:(KABubbleWindowController *) bubble;
- (void) bubbleDidFadeIn:(KABubbleWindowController *) bubble;

- (void) bubbleWillFadeOut:(KABubbleWindowController *) bubble;
- (void) bubbleDidFadeOut:(KABubbleWindowController *) bubble;
@end
