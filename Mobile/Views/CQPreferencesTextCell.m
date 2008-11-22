#import "CQPreferencesTextCell.h"

@implementation CQPreferencesTextCell
- (id) initWithFrame:(CGRect) frame reuseIdentifier:(NSString *) reuseIdentifier {
	if( ! ( self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier] ) )
		return nil;

	self.backgroundColor = nil;
	self.opaque = NO;

	_textField = [[UITextField alloc] initWithFrame:CGRectZero];
	_label = [[UILabel alloc] initWithFrame:CGRectZero];

	_label.font = [UIFont boldSystemFontOfSize:18.];
	_label.textColor = self.textColor;
	_label.highlightedTextColor = self.selectedTextColor;
	_label.backgroundColor = nil;
	_label.opaque = NO;

	_textField.delegate = self;
	_textField.textAlignment = UITextAlignmentLeft;
	_textField.contentVerticalAlignment = UIControlContentVerticalAlignmentTop;
	_textField.font = [UIFont systemFontOfSize:14.];
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
	[_textField release];
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

	_label.highlighted = selected;
}

- (void) setAccessoryType:(UITableViewCellAccessoryType) type {
	super.accessoryType = type;

	if (type == UITableViewCellAccessoryDisclosureIndicator)
		_textField.textAlignment = UITextAlignmentRight;
	else _textField.textAlignment = UITextAlignmentLeft;
}

- (void) prepareForReuse {
	[super prepareForReuse];

	self.label = @"";
	self.text = @"";
	self.target = nil;
	self.textEditAction = NULL;
	self.accessoryType = UITableViewCellAccessoryNone;
	self.textField.placeholder = @"";
	self.textField.secureTextEntry = NO;
	self.textField.keyboardType = UIKeyboardTypeDefault;
	self.textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
	self.textField.autocorrectionType = UITextAutocorrectionTypeDefault;

	[self.textField resignFirstResponder];
}

- (void) layoutSubviews {
	[super layoutSubviews];

	CGRect contentRect = self.contentView.frame;

	NSString *originalText = [_textField.text retain];
	BOOL showingTextField = NO;
	if (originalText.length || _textField.placeholder.length) {
		_textField.hidden = NO;
		showingTextField = YES;

		_textField.text = @"Qwerty"; // Temporary text to workaround a bug where sizeThatFits: returns zero height when there is only a placeholder.

		const CGFloat rightMargin = (self.accessoryType == UITableViewCellAccessoryDisclosureIndicator ? 2. : 10.);

		CGRect frame = _textField.frame;
		frame.size = [_textField sizeThatFits:_textField.bounds.size];
		frame.origin.x = 120.;
		frame.origin.y = round((contentRect.size.height / 2.) - (frame.size.height / 2.));
		frame.size.width = (contentRect.size.width - frame.origin.x - rightMargin);
		_textField.frame = frame;

		_textField.text = originalText; // Restore the original text.
	} else {
		_textField.hidden = YES;
	}

	[originalText release];

	CGRect frame = _label.frame;
	frame.size = [_label sizeThatFits:_label.bounds.size];
	frame.origin.x = 10.;
	frame.origin.y = round((contentRect.size.height / 2.) - (frame.size.height / 2.));
	if (showingTextField)
		frame.size.width = (_textField.frame.origin.x - frame.origin.x - 10.);
	else frame.size.width = (contentRect.size.width - frame.origin.x - 10.);
	_label.frame = frame;
}

@synthesize textEditAction = _textEditAction;

- (BOOL) textFieldShouldBeginEditing:(UITextField *) textField {
	return self.accessoryType == UITableViewCellAccessoryNone;
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
