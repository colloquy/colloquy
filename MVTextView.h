#import <AppKit/NSTextView.h>

@interface MVTextView : NSTextView {
    NSDictionary *typingAttributes;
}
- (void) reset:(id) sender;

- (void) bold:(id) sender;
- (void) italic:(id) sender;
@end

@interface NSObject (MVTextViewDelegate)
- (BOOL) textView:(NSTextView *) textView enterHit:(NSEvent *) event;
- (BOOL) textView:(NSTextView *) textView returnHit:(NSEvent *) event;
- (BOOL) textView:(NSTextView *) textView tabHit:(NSEvent *) event;
- (BOOL) textView:(NSTextView *) textView upArrowHit:(NSEvent *) event;
- (BOOL) textView:(NSTextView *) textView downArrowHit:(NSEvent *) event;
@end
