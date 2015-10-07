#import "CQPreferencesTextViewController.h"

NS_ASSUME_NONNULL_BEGIN

@implementation CQPreferencesTextViewController {
	UITextView *_textView;
}

- (void) loadView {
	_textView = [[UITextView alloc] initWithFrame:CGRectZero];
	_textView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin);
	_textView.dataDetectorTypes = (UIDataDetectorTypeLink | UIDataDetectorTypePhoneNumber);
	_textView.editable = NO;
	_textView.font = [UIFont systemFontOfSize:[UIFont systemFontSize] + 1.];
	_textView.text = self.text;
	_textView.textAlignment = NSTextAlignmentJustified;

	self.view = _textView;
}

#pragma mark -

- (void) setText:(NSString *) text {
	_text = [text copy];
	_textView.text = text;
}
@end

NS_ASSUME_NONNULL_END
