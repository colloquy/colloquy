#import <AppKit/NSView.h>

@interface KABubbleWindowView : NSView {
	NSImage				*_icon;
	NSString			*_title;
	NSAttributedString  *_text;
}

- (void) setIcon:(NSImage *) icon;
- (void) setTitle:(NSString *) title;
- (void) setAttributedText:(NSAttributedString *) text;
- (void) setText:(NSString *) text;
@end
