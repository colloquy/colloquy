#import <AppKit/NSTextView.h>

@interface MVTextView : NSTextView {
    NSDictionary *typingAttributes;
	
	NSSize			lastPostedSize;
	NSSize			_desiredSizeCached;
}
- (BOOL)checkKeyEvent:(NSEvent *)event;

- (void) reset:(id) sender;
- (void) bold:(id) sender;
- (void) italic:(id) sender;
@end

@interface NSObject (MVTextViewDelegate)
- (BOOL) textView:(NSTextView *) textView functionKeyPressed:(NSEvent *) event;
- (BOOL) textView:(NSTextView *) textView enterKeyPressed:(NSEvent *) event;
- (BOOL) textView:(NSTextView *) textView returnKeyPressed:(NSEvent *) event;
- (BOOL) textView:(NSTextView *) textView escapeKeyPressed:(NSEvent *) event;
- (BOOL) textView:(NSTextView *) textView tabKeyPressed:(NSEvent *) event;
@end
