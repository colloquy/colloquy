#import <WebKit/WebView.h>

@interface JVWebView : WebView {
	IBOutlet NSTextView *nextTextView;
}
- (NSTextView *) nextTextView;
- (void) setNextTextView:(NSTextView *) textView;
@end
