@interface KABubbleWindowView : NSView {
	NSImage *_icon;
	NSString *_title;
	NSAttributedString *_text;
	SEL _action;
	id _target;
}
- (void) setIcon:(NSImage *) icon;
- (void) setTitle:(NSString *) title;
- (void) setAttributedText:(NSAttributedString *) text;
- (void) setText:(NSString *) text;

@property (assign) id target;

@property SEL action;
@end
