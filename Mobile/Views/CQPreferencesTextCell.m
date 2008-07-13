#import "CQPreferencesTextCell.h"

@implementation CQPreferencesTextCell
- (id) initWithFrame:(CGRect) frame reuseIdentifier:(NSString *) reuseIdentifier {
	if( ! ( self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier] ) )
		return nil;

	_textField = [[UITextField alloc] initWithFrame:CGRectZero];
	_label = [[UILabel alloc] initWithFrame:CGRectZero];

	_textField.leftView = _label;
	_textField.leftViewMode = UITextFieldViewModeAlways;

	[self.contentView addSubview:_textField];

	_textField.font = [UIFont systemFontOfSize:14.];
	_textField.textColor = [UIColor colorWithRed:0.19607843 green:0.29803922 blue:0.84313725 alpha:1.];

	_label.font = [UIFont boldSystemFontOfSize:18.];
	_label.textColor = self.textColor;
	_label.highlightedTextColor = self.selectedTextColor;

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

- (void) setSelected:(BOOL) selected animated:(BOOL) animated {
	[super setSelected:selected animated:animated];

	UIColor *backgroundColor = nil;
	if( selected || animated ) backgroundColor = nil;
	else backgroundColor = [UIColor whiteColor];

	_textField.backgroundColor = backgroundColor;
	_textField.opaque = !selected && !animated;

	_label.backgroundColor = backgroundColor;
	_label.highlighted = selected;
	_label.opaque = !selected && !animated;
}

- (void) layoutSubviews {
	[super layoutSubviews];

	CGRect contentRect = self.contentView.bounds;

	_textField.frame = contentRect;
}
@end
