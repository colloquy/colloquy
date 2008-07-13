#import "CQChatTableCell.h"
#import "CQChatController.h"

@implementation CQChatTableCell
- (id) initWithFrame:(CGRect) frame reuseIdentifier:(NSString *) reuseIdentifier {
	if( ! ( self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier] ) )
		return nil;

	_iconImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
//	_firstChatLine = [[UILabel alloc] initWithFrame:CGRectZero];
//	_secondChatLine = [[UILabel alloc] initWithFrame:CGRectZero];

	[self.contentView addSubview:_iconImageView];
	[self.contentView addSubview:_nameLabel];
//	[self.contentView addSubview:_firstChatLine];
//	[self.contentView addSubview:_secondChatLine];

	_nameLabel.font = [UIFont boldSystemFontOfSize:18.];
	_nameLabel.textColor = self.textColor;
	_nameLabel.highlightedTextColor = self.selectedTextColor;

//	_firstChatLine.font = [UIFont systemFontOfSize:14.];
//	_firstChatLine.textColor = [UIColor grayColor];
//	_firstChatLine.highlightedTextColor = self.selectedTextColor;

//	_secondChatLine.font = [UIFont systemFontOfSize:14.];
//	_secondChatLine.textColor = [UIColor grayColor];
//	_secondChatLine.highlightedTextColor = self.selectedTextColor;

	return self;
}

- (void) dealloc {
	[_iconImageView release];
	[_nameLabel release];
//	[_firstChatLine release];
//	[_secondChatLine release];

	[super dealloc];
}

- (void) takeValuesFromChatViewController:(id <CQChatViewController>) controller {
	self.name = controller.title;
	self.icon = controller.icon;
}

- (NSString *) name {
	return _nameLabel.text;
}

- (void) setName:(NSString *) name {
	_nameLabel.text = name;
}

- (UIImage *) icon {
	return _iconImageView.image;
}

- (void) setIcon:(UIImage *) icon {
	_iconImageView.image = icon;
}

/*
- (NSString *) firstChatLineText {
	return _firstChatLine.text;
}

- (void) setFirstChatLineText:(NSString *) text {
	_firstChatLine.text = text;
	[self setNeedsLayout];
}

- (NSString *) secondChatLineText {
	return _secondChatLine.text;
}

- (void) setSecondChatLineText:(NSString *) text {
	_secondChatLine.text = text;
	[self setNeedsLayout];
}
*/

- (void) setSelected:(BOOL) selected animated:(BOOL) animated {
	[super setSelected:selected animated:animated];

	UIColor *backgroundColor = nil;
	if( selected || animated ) backgroundColor = nil;
	else backgroundColor = [UIColor whiteColor];

	_nameLabel.backgroundColor = backgroundColor;
	_nameLabel.highlighted = selected;
	_nameLabel.opaque = !selected && !animated;

//	_firstChatLine.backgroundColor = backgroundColor;
//	_firstChatLine.highlighted = selected;
//	_firstChatLine.opaque = !selected && !animated;

//	_secondChatLine.backgroundColor = backgroundColor;
//	_secondChatLine.highlighted = selected;
//	_secondChatLine.opaque = !selected && !animated;
}

- (void) layoutSubviews {
	[super layoutSubviews];

#define TOP_MARGIN 10.
#define LEFT_MARGIN 10.
#define RIGHT_MARGIN 10.
#define ICON_RIGHT_MARGIN 10.

	CGRect contentRect = self.contentView.bounds;

	CGRect frame = _iconImageView.frame;
	frame.size = [_iconImageView sizeThatFits:_iconImageView.bounds.size];
	frame.origin.x = contentRect.origin.x + LEFT_MARGIN;
	frame.origin.y = contentRect.origin.y + TOP_MARGIN;
	_iconImageView.frame = frame;

	frame = _nameLabel.frame;
	frame.size = [_nameLabel sizeThatFits:_nameLabel.bounds.size];
	frame.origin.x = CGRectGetMaxX(_iconImageView.frame) + ICON_RIGHT_MARGIN;
	frame.origin.y = contentRect.origin.y + TOP_MARGIN;
	frame.size.width = contentRect.size.width  - frame.origin.x - RIGHT_MARGIN;
	_nameLabel.frame = frame;
}
@end
