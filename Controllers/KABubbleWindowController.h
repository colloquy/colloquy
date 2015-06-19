#import <Cocoa/Cocoa.h>

@class KABubbleWindowController;

@protocol KABubbleWindowControllerDelegate <NSObject>
@optional
- (void) bubbleWillFadeIn:(KABubbleWindowController *) bubble;
- (void) bubbleDidFadeIn:(KABubbleWindowController *) bubble;

- (void) bubbleWillFadeOut:(KABubbleWindowController *) bubble;
- (void) bubbleDidFadeOut:(KABubbleWindowController *) bubble;
@end

@interface KABubbleWindowController : NSWindowController <NSWindowDelegate> {
	id _self;
	__unsafe_unretained id <KABubbleWindowControllerDelegate> _delegate;
	NSTimer *_animationTimer;
	NSUInteger _depth;
	BOOL _autoFadeOut;
	SEL _action;
	__weak id _target;
	id _representedObject;
}
+ (KABubbleWindowController *) bubble;
+ (KABubbleWindowController *) bubbleWithTitle:(NSString *) title text:(id) text icon:(NSImage *) icon;

- (void) startFadeIn;
- (void) startFadeOut;

@property BOOL automaticallyFadesOut;
@property (weak) id target;
@property SEL action;
@property id representedObject;
@property (unsafe_unretained) id <KABubbleWindowControllerDelegate> delegate;
@end
