@class DOMHTMLElement;

@interface CQStyleView : UIScrollView {
	UIWebView *_webView;
	BOOL _wasScrolling;
	BOOL _clickedLink;
}
- (CGPoint) bottomScrollOffset;
- (void) scrollToBottom;
- (void) scrollToBottomAnimated:(BOOL) animate;

- (DOMHTMLElement *) body;
@end

@interface NSObject (CQStyleViewDelegate)
- (void) styleViewDidAcceptFocusClick:(CQStyleView *) view;
@end
