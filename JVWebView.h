@interface JVWebView : WebView {
	IBOutlet NSTextView *nextTextView;
	BOOL forwarding;
}
- (NSTextView *) nextTextView;
- (void) setNextTextView:(NSTextView *) textView;
@end
