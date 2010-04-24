#import "CQColloquyApplication.h"

#import "CQPreferencesTextViewCell.h"
#import "CQTextView.h"

#import "UIDeviceAdditions.h"

@interface CQPreferencesTextViewCell (Private)
@property (nonatomic, readonly) CGFloat height;
@end

@implementation CQPreferencesTextViewCell
@synthesize textView = _textView;

- (id) initWithStyle:(UITableViewCellStyle) style reuseIdentifier:(NSString *) reuseIdentifier {
	if (!(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
		return nil;

	_textView = [[CQTextView alloc] initWithFrame:CGRectZero];
	_textView.editable = YES;
	_textView.scrollEnabled = [[UIDevice currentDevice] isPadModel] ? NO : YES;
	_textView.font = [UIFont systemFontOfSize:17.];
	_textView.keyboardType = UIKeyboardTypeDefault;
	_textView.textAlignment = UITextAlignmentLeft;
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
	[_textView release];

	[super dealloc];
}

#pragma mark -

- (void) prepareForReuse {
	[super prepareForReuse];

	_textView.text = @"";
	_textView.editable = YES;
	_textView.scrollEnabled = ![[UIDevice currentDevice] isPadModel];
	_textView.textColor = [UIColor blackColor];
	_textView.textAlignment = UITextAlignmentLeft;
	_textView.font = [UIFont systemFontOfSize:17.];
	_textView.keyboardType = UIKeyboardTypeDefault;
	_textView.autocapitalizationType = UITextAutocapitalizationTypeSentences;
	_textView.autocorrectionType = UITextAutocorrectionTypeDefault;
	_textView.enablesReturnKeyAutomatically = NO;
	_textView.returnKeyType = UIReturnKeyDefault;

	[_textView endEditing:YES];
	[_textView resignFirstResponder];

	self.target = nil;
	self.accessoryType = UITableViewCellAccessoryNone;
	self.selectionStyle = UITableViewCellSelectionStyleNone;
}

#pragma mark -

+ (CGFloat) height {
	CGSize size = [UIScreen mainScreen].bounds.size;
	BOOL landscapeOrientation = UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation);

	if ([[UIDevice currentDevice] isPadModel]) {
		if (landscapeOrientation)
			return (CGFloat)MIN(size.height, size.width) / 3;
		return (CGFloat)MIN(size.height, size.width) / 2;
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

	[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.25];
	[UIView setAnimationBeginsFromCurrentState:YES];

	_textView.frame = CGRectMake(0, 0, self.contentView.frame.size.width, height);

	[UIView commitAnimations];
}

#pragma mark -

- (BOOL) resignFirstResponder {
	if (![super resignFirstResponder])
		return NO;

	[_textView endEditing:YES];
	return [_textView resignFirstResponder];
}
@end
