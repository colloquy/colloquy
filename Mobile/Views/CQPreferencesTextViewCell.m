#import "CQColloquyApplication.h"

#import "CQPreferencesTextViewCell.h"
#import "CQTextView.h"

NS_ASSUME_NONNULL_BEGIN

@interface CQPreferencesTextViewCell (Private)
@property (nonatomic, readonly) CGFloat height;
@end

@implementation CQPreferencesTextViewCell
- (instancetype) initWithStyle:(UITableViewCellStyle) style reuseIdentifier:(NSString *__nullable) reuseIdentifier {
	if (!(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
		return nil;

	_textView = [[CQTextView alloc] initWithFrame:CGRectZero];
#if !SYSTEM(TV)
	_textView.editable = YES;
#endif
	_textView.scrollEnabled = !self.window.isFullscreen;
	_textView.font = [UIFont systemFontOfSize:17.];
	_textView.keyboardType = UIKeyboardTypeDefault;
	_textView.textAlignment = NSTextAlignmentLeft;
	_textView.autocapitalizationType = UITextAutocapitalizationTypeSentences;
	_textView.autocorrectionType = UITextAutocorrectionTypeDefault;
	_textView.enablesReturnKeyAutomatically = NO;
	_textView.returnKeyType = UIReturnKeyDone;

	[self.contentView addSubview:_textView];

	self.selectionStyle = UITableViewCellSelectionStyleNone;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(layoutSubviews) name:UIKeyboardDidShowNotification object:nil];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_textView endEditing:YES];
	[_textView resignFirstResponder];
}

#pragma mark -

- (void) prepareForReuse {
	[super prepareForReuse];

	_textView.text = @"";
#if !SYSTEM(TV)
	_textView.editable = YES;
#endif
	_textView.scrollEnabled = !self.window.isFullscreen;
	_textView.textColor = [UIColor blackColor];
	_textView.textAlignment = NSTextAlignmentLeft;
	_textView.font = [UIFont systemFontOfSize:17.];
	_textView.keyboardType = UIKeyboardTypeDefault;
	_textView.autocapitalizationType = UITextAutocapitalizationTypeSentences;
	_textView.autocorrectionType = UITextAutocorrectionTypeDefault;
	_textView.enablesReturnKeyAutomatically = NO;
	_textView.returnKeyType = UIReturnKeyDefault;

	[_textView endEditing:YES];
	[_textView resignFirstResponder];

	self.accessoryType = UITableViewCellAccessoryNone;
	self.selectionStyle = UITableViewCellSelectionStyleNone;
}

- (void) traitCollectionDidChange:(nullable UITraitCollection *) previousTraitCollection {
	_textView.scrollEnabled = !self.window.isFullscreen;
}

#pragma mark -

+ (CGFloat) height {
	CGSize size = [UIScreen mainScreen].bounds.size;
#if !SYSTEM(TV)
	BOOL landscapeOrientation = UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation);
#else
	BOOL landscapeOrientation = YES;
#endif

	if ([UIApplication sharedApplication].keyWindow.isFullscreen) {
		if (landscapeOrientation)
			return (CGFloat)MIN(size.height, size.width) / 3;
		return (CGFloat)MIN(size.height, size.width) / 2;
	} else if ([[UIDevice currentDevice] isRetina]) {
		if (landscapeOrientation)
			return (CGFloat)MIN(size.height, size.width) / 3;
		return (CGFloat)MAX(size.height, size.width) / 2;
	} else {
		if (landscapeOrientation)
			return floor(((CGFloat)MIN(size.height, size.width) / 4));
		return ((CGFloat)MAX(size.height, size.width) / 3);
	}
}

- (CGFloat) height {
	return [CQPreferencesTextViewCell height];
}

#pragma mark -

- (void) layoutSubviews {
	[super layoutSubviews];

	CGFloat height = self.height;
	if (height == _textView.frame.size.height && _textView.frame.size.width == self.contentView.frame.size.width)
		return;

	[UIView animateWithDuration:.25 delay:0. options:(UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState) animations:^{
		_textView.frame = CGRectMake(0, 0, self.contentView.frame.size.width, height);
	} completion:NULL];
}

#pragma mark -

- (BOOL) resignFirstResponder {
	if (![super resignFirstResponder])
		return NO;

	[_textView endEditing:YES];
	return [_textView resignFirstResponder];
}
@end

NS_ASSUME_NONNULL_END
