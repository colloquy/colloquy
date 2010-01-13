#import "CQPreferencesTextCell.h"

static CQPreferencesTextCell *currentEditingCell;

@implementation CQPreferencesTextCell
+ (CQPreferencesTextCell *) currentEditingCell {
	return currentEditingCell;
}

- (id) initWithStyle:(UITableViewCellStyle) style reuseIdentifier:(NSString *) reuseIdentifier {
	if (!(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
		return nil;

	self.selectionStyle = UITableViewCellSelectionStyleNone;

	_textField = [[UITextField alloc] initWithFrame:CGRectZero];

	_textField.delegate = self;
	_textField.textAlignment = UITextAlignmentLeft;
	_textField.contentVerticalAlignment = UIControlContentVerticalAlignmentTop;
	_textField.font = [UIFont systemFontOfSize:17.];
	_textField.adjustsFontSizeToFitWidth = YES;
	_textField.minimumFontSize = 14.;
	_textField.textColor = [UIColor colorWithRed:(50. / 255.) green:(79. / 255.) blue:(133. / 255.) alpha:1.];
	_textField.enablesReturnKeyAutomatically = NO;
	_textField.returnKeyType = UIReturnKeyDone;

	CGRect subviewFrame = _textField.frame;
	subviewFrame.size.height = [_textField sizeThatFits:_textField.bounds.size].height;
	_textField.frame = subviewFrame;

	_enabled = YES;

	[self.contentView addSubview:_textField];

	return self;
}

- (void) dealloc {
	[_textField resignFirstResponder];
	_textField.delegate = nil;

	[_textField autorelease]; // Use autorelease to prevent a crash.

	[super dealloc];
}

#pragma mark -

@synthesize textField = _textField;

- (void) setSelected:(BOOL) selected animated:(BOOL) animated {
	[super setSelected:selected animated:animated];

	if (self.selectionStyle == UITableViewCellSelectionStyleNone)
		return;

	if (selected) _textField.textColor = [UIColor whiteColor];
	else if (!_enabled) _textField.textColor = [UIColor colorWithRed:(50. / 255.) green:(79. / 255.) blue:(133. / 255.) alpha:0.5];
	else _textField.textColor = [UIColor colorWithRed:(50. / 255.) green:(79. / 255.) blue:(133. / 255.) alpha:1.];
}

- (void) prepareForReuse {
	[super prepareForReuse];

	_enabled = YES;
	_textEditAction = NULL;

	_textField.text = @"";
	_textField.placeholder = @"";
	_textField.keyboardType = UIKeyboardTypeDefault;
	_textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
	_textField.autocorrectionType = UITextAutocorrectionTypeDefault;
	_textField.textColor = [UIColor colorWithRed:(50. / 255.) green:(79. / 255.) blue:(133. / 255.) alpha:1.];
	_textField.clearButtonMode = UITextFieldViewModeNever;
	_textField.enabled = YES;

	[_textField endEditing:YES];
	[_textField resignFirstResponder];

	self.textLabel.text = @"";
	self.target = nil;
	self.accessoryType = UITableViewCellAccessoryNone;
}

- (void) layoutSubviews {
	[super layoutSubviews];

	CGRect contentRect = self.contentView.frame;

	UILabel *label = self.textLabel;

	BOOL showingLabel = (label.text.length > 0);
	BOOL showingTextField = (_textField.text.length || _textField.placeholder.length);

	if (showingLabel) {
		label.hidden = NO;

		CGRect frame = label.frame;
		if (!showingTextField)
			frame.size.width = (contentRect.size.width - frame.origin.x - 10.);
		else frame.size.width = [label sizeThatFits:label.bounds.size].width;
		label.frame = frame;
	} else {
		label.hidden = YES;
	}

	if (showingTextField) {
		_textField.hidden = NO;

		const CGFloat leftMargin = 10.;
		CGFloat rightMargin = 10.;
		if (_textField.clearButtonMode == UITextFieldViewModeAlways)
			rightMargin = 0.;
		else if (self.accessoryType == UITableViewCellAccessoryDisclosureIndicator)
			rightMargin = 4.;

		CGRect frame = _textField.frame;
		NSAssert(frame.size.height > 0., @"A height is assumed to be set in initWithFrame:.");
		frame.origin.x = (showingLabel ? MAX(CGRectGetMaxX(label.frame) + leftMargin, 125.) : leftMargin);
		frame.origin.y = round((contentRect.size.height / 2.) - (frame.size.height / 2.));
		frame.size.width = (contentRect.size.width - frame.origin.x - rightMargin);
		_textField.frame = frame;
	} else {
		_textField.hidden = YES;
	}
}

@synthesize enabled = _enabled;

- (void) setEnabled:(BOOL) enabled {
	_textField.enabled = enabled;

	_enabled = enabled;

	if (_enabled) _textField.textColor = [UIColor colorWithRed:(50. / 255.) green:(79. / 255.) blue:(133. / 255.) alpha:1.];
	else _textField.textColor = [UIColor colorWithRed:(50. / 255.) green:(79. / 255.) blue:(133. / 255.) alpha:0.5];
}

@synthesize textEditAction = _textEditAction;

- (BOOL) textFieldShouldBeginEditing:(UITextField *) textField {
	return _enabled;
}

- (BOOL) textFieldShouldReturn:(UITextField *) textField {
	[textField resignFirstResponder];
	return YES;
}

- (void) textFieldDidBeginEditing:(UITextField *) textField {
	id old = currentEditingCell;
	currentEditingCell = [self retain];
	[old release];
}

- (void) textFieldDidEndEditing:(UITextField *) textField {
	if (self.textEditAction && (!self.target || [self.target respondsToSelector:self.textEditAction]))
		[[UIApplication sharedApplication] sendAction:self.textEditAction to:self.target from:self forEvent:nil];

	if (currentEditingCell == self) {
		id old = currentEditingCell;
		currentEditingCell = nil;
		[old release];
	}
}
@end
