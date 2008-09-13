#import "CQPreferencesTextCell.h"

@implementation CQPreferencesTextCell
- (id) initWithFrame:(CGRect) frame reuseIdentifier:(NSString *) reuseIdentifier {
	if( ! ( self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier] ) )
		return nil;

	self.backgroundColor = [UIColor clearColor];
	self.opaque = NO;

	_textField = [[UITextField alloc] initWithFrame:CGRectZero];
	_label = [[UILabel alloc] initWithFrame:CGRectZero];

	_label.font = [UIFont boldSystemFontOfSize:18.];
	_label.textColor = self.textColor;
	_label.highlightedTextColor = self.selectedTextColor;
	_label.backgroundColor = [UIColor clearColor];
	_label.opaque = NO;

	_textField.textAlignment = UITextAlignmentLeft;
	_textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
	_textField.font = [UIFont systemFontOfSize:14.];
	_textField.textColor = [UIColor colorWithRed:0.235294117647059 green:0.341176470588235 blue:0.545098039215686 alpha:1.];
	_textField.backgroundColor = [UIColor clearColor];
	_textField.opaque = NO;

	[self.contentView addSubview:_label];
	[self.contentView addSubview:_textField];

	return self;
}

- (void) dealloc {
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
}

- (NSString *) placeholder {
	return _textField.placeholder;
}

- (void) setPlaceholder:(NSString *) placeholder {
	_textField.placeholder = placeholder;
}

- (BOOL) isSecureTextEntry {
	return _textField.secureTextEntry;
}

- (void) setSecureTextEntry:(BOOL) flag {
	_textField.secureTextEntry = flag;
}

- (void) setSelected:(BOOL) selected animated:(BOOL) animated {
	[super setSelected:selected animated:animated];

	_label.highlighted = selected;
}

- (void) prepareForReuse {
	self.label = @"";
	self.text = @"";
	self.placeholder = @"";
	self.secureTextEntry = NO;
}

- (void) layoutSubviews {
	[super layoutSubviews];

	CGRect contentRect = self.contentView.bounds;
	contentRect.origin.x = 10.;
	contentRect.size.width = 130.;

	_label.frame = contentRect;

	contentRect = self.contentView.bounds;
	contentRect.origin.x = 150.;
	contentRect.size.width -= 160.;

	_textField.frame = contentRect;
}
@end
