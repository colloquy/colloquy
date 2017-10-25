#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class KABubbleWindowController;

@protocol KABubbleWindowControllerDelegate <NSObject>
@optional
- (void) bubbleWillFadeIn:(KABubbleWindowController *) bubble NS_SWIFT_NAME(bubbleWillFadeIn(_:));
- (void) bubbleDidFadeIn:(KABubbleWindowController *) bubble NS_SWIFT_NAME(bubbleDidFadeIn(_:));

- (void) bubbleWillFadeOut:(KABubbleWindowController *) bubble;
- (void) bubbleDidFadeOut:(KABubbleWindowController *) bubble;
@end

@interface KABubbleWindowController : NSWindowController <NSWindowDelegate> {
	id _self;
	NSTimer *_animationTimer;
	NSUInteger _depth;
}

- (instancetype) init;
+ (instancetype) bubble NS_SWIFT_UNAVAILABLE("Use KABubbleWindowController() instead");
+ (instancetype) bubbleWithTitle:(nullable NSString *) title text:(nullable id) text icon:(nullable NSImage *) icon NS_SWIFT_NAME(init(title:text:icon:));

- (void) startFadeIn;
- (void) startFadeOut;

@property BOOL automaticallyFadesOut;
@property (weak) id target;
@property (nullable) SEL action;
@property (strong, nullable) id representedObject;
@property (weak) id <KABubbleWindowControllerDelegate> delegate;
@end

NS_ASSUME_NONNULL_END
