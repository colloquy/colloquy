#import "CQPreferencesTextCell.h"

@implementation CQPreferencesTextCell
- (id) initWithFrame:(CGRect) frame reuseIdentifier:(NSString *) reuseIdentifier {
	if (!(self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier]))
		return nil;

	self.selectionStyle = UITableViewCellSelectionStyleNone;
	self.backgroundColor = [UIColor whiteColor];
	self.opaque = YES;

	_textField = [[UITextField alloc] initWithFrame:CGRectZero];
	_label = [[UILabel alloc] initWithFrame:CGRectZero];

	_label.font = [UIFont boldSystemFontOfSize:17.];
	_label.textColor = self.textColor;
	_label.highlightedTextColor = self.selectedTextColor;
	_label.backgroundColor = nil;
	_label.opaque = NO;

	_textField.delegate = self;
	_textField.textAlignment = UITextAlignmentLeft;
	_textField.contentVerticalAlignment = UIControlContentVerticalAlignmentTop;
	_textField.font = [UIFont systemFontOfSize:17.];
	_textField.adjustsFontSizeToFitWidth = YES;
	_textField.minimumFontSize = 14.;
	_textField.textColor = [UIColor colorWithRed:(50. / 255.) green:(79. / 255.) blue:(133. / 255.) alpha:1.];
	_textField.enablesReturnKeyAutomatically = NO;
	_textField.returnKeyType = UIReturnKeyDone;
	_textField.backgroundColor = nil;
	_textField.opaque = NO;

	[self.contentView addSubview:_label];
	[self.contentView addSubview:_textField];

	return self;
}

- (void) dealloc {
	[_textField resignFirstResponder];
	_textField.delegate = nil;

	[_textField autorelease]; // Use autorelease to prevent a crash.
	[_label release];

	[super dealloc];
}

@synthesize textField = _textField;

- (NSString *) label {
	return _label.text;
}

- (void) setLabel:(NSString *) labelText {
	_label.text = labelText;
}

- (NSString *) text {
	return _textField.text;
}

- (void) setText:(NSString *) text {
	_textField.text = text;

	[self setNeedsLayout];
}

- (void) setSelected:(BOOL) selected animated:(BOOL) animated {
	[super setSelected:selected animated:animated];

	if (self.selectionStyle == UITableViewCellSelectionStyleNone)
		return;

	if (selected) _textField.textColor = [UIColor whiteColor];
	else _textField.textColor = [UIColor colorWithRed:(50. / 255.) green:(79. / 255.) blue:(133. / 255.) alpha:1.];
}

- (void) setAccessoryType:(UITableViewCellAccessoryType) type {
	super.accessoryType = type;

	if (type == UITableViewCellAccessoryDisclosureIndicator) {
		self.selectionStyle = UITableViewCellSelectionStyleBlue;
		_textField.textAlignment = UITextAlignmentRight;
		_textField.adjustsFontSizeToFitWidth = NO;
		_textField.userInteractionEnabled = NO;
	} else {
		self.selectionStyle = UITableViewCellSelectionStyleNone;
		_textField.textAlignment = UITextAlignmentLeft;
		_textField.adjustsFontSizeToFitWidth = YES;
		_textField.userInteractionEnabled = YES;
	}
}

- (void) prepareForReuse {
	[super prepareForReuse];

	self.label = @"";
	self.text = @"";
	self.target = nil;
	self.textEditAction = NULL;
	self.accessoryType = UITableViewCellAccessoryNone;
	self.textField.placeholder = @"";
	self.textField.keyboardType = UIKeyboardTypeDefault;
	self.textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
	self.textField.autocorrectionType = UITextAutocorrectionTypeDefault;

	[self.textField resignFirstResponder];
}

- (void) layoutSubviews {
	[super layoutSubviews];

	CGRect contentRect = self.contentView.frame;
	NSString *originalText = [_textField.text retain];

	BOOL showingLabel = (_label.text.length > 0);
	BOOL showingTextField = (originalText.length || _textField.placeholder.length);

	if (showingLabel) {
		_label.hidden = NO;

		CGRect frame = _label.frame;
		frame.size = [_label sizeThatFits:_label.bounds.size];
		frame.origin.x = 10.;
		frame.origin.y = round((contentRect.size.height / 2.) - (frame.size.height / 2.)) - 1.;
		if (!showingTextField)
			frame.size.width = (contentRect.size.width - frame.origin.x - 10.);
		_label.frame = frame;
	} else {
		_label.hidden = YES;
	}

	if (showingTextField) {
		_textField.hidden = NO;

		_textField.text = @"Qwerty"; // Temporary text to workaround a bug where sizeThatFits: returns zero height when there is only a placeholder.

		const CGFloat leftMargin = 10.;
		CGFloat rightMargin = 10.;
		if (_textField.clearButtonMode == UITextFieldViewModeAlways)
			rightMargin = 0.;
		else if (self.accessoryType == UITableViewCellAccessoryDisclosureIndicator)
			rightMargin = 2.;

		CGRect frame = _textField.frame;
		frame.size = [_textField sizeThatFits:_textField.bounds.size];
		frame.origin.x = (showingLabel ? MAX(CGRectGetMaxX(_label.frame) + leftMargin, 125.) : leftMargin);
		frame.origin.y = round((contentRect.size.height / 2.) - (frame.size.height / 2.)) - 1.;
		frame.size.width = (contentRect.size.width - frame.origin.x - rightMargin);
		_textField.frame = frame;

		_textField.text = originalText; // Restore the original text.
	} else {
		_textField.hidden = YES;
	}

	[originalText release];
}

@synthesize textEditAction = _textEditAction;

- (BOOL) textFieldShouldBeginEditing:(UITextField *) textField {
	return (self.accessoryType == UITableViewCellAccessoryNone || self.accessoryType == UITableViewCellAccessoryDetailDisclosureButton);
}

- (BOOL) textFieldShouldReturn:(UITextField *) textField {
	[textField resignFirstResponder];
	return YES;
}

- (void) textFieldDidEndEditing:(UITextField *) textField {
	if (self.textEditAction && (!self.target || [self.target respondsToSelector:self.textEditAction]))
		[[UIApplication sharedApplication] sendAction:self.textEditAction to:self.target from:self forEvent:nil];
}
@end
