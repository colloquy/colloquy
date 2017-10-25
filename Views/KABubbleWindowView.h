#import <Cocoa/Cocoa.h>

@interface KABubbleWindowView : NSView {
	NSImage *_icon;
	NSString *_title;
	NSAttributedString *_text;
	SEL _action;
	__unsafe_unretained id _target;
}
@property (nonatomic, copy) NSImage *icon;
- (void) setTitle:(NSString *) title;
- (void) setAttributedText:(NSAttributedString *) text;
- (void) setText:(NSString *) text;

@property (assign) id target;

@property SEL action;
@end
