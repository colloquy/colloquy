#import "CQPreferencesTextViewController.h"

NS_ASSUME_NONNULL_BEGIN

@implementation CQPreferencesTextViewController {
	UITextView *_textView;
}

- (void) loadView {
	_textView = [[UITextView alloc] initWithFrame:CGRectZero];
	_textView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin);
#if !SYSTEM(TV)
	_textView.dataDetectorTypes = (UIDataDetectorTypeLink | UIDataDetectorTypePhoneNumber);
	_textView.editable = NO;
#endif
	_textView.font = [UIFont systemFontOfSize:19.];
	_textView.text = self.text;
	_textView.textAlignment = NSTextAlignmentJustified;

	self.view = _textView;
}

- (void) viewDidLoad {
	[super viewDidLoad];

	[self.tableView hideEmptyCells];
}

#pragma mark -

- (void) setText:(NSString *) text {
	_text = [text copy];
	_textView.text = text;
}
@end

NS_ASSUME_NONNULL_END
