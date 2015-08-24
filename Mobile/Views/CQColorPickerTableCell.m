#import "CQColorPickerTableCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface CQColorPickerTableCell ()
@property (atomic, strong) NSMapTable *colorToButtonMap;
@property (atomic, strong) NSMapTable *buttonToColorMap;
@end

@implementation  CQColorPickerTableCell
- (instancetype) initWithStyle:(UITableViewCellStyle) style reuseIdentifier:(NSString *__nullable) reuseIdentifier {
	if (!(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
		return nil;

	self.selectionStyle = UITableViewCellSelectionStyleNone;
	self.selectedBackgroundView = [[UIView alloc] initWithFrame:CGRectZero];

	return self;
}

- (void) setActiveColor:(UIColor *) activeColor {
	_activeColor = [activeColor copy];

	[self setNeedsLayout];
	[self layoutIfNeeded];
}

- (void) setColors:(NSArray *) colors {
	[self.contentView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

	_colors = [colors copy];

	_colorToButtonMap = [NSMapTable strongToStrongObjectsMapTable];
	_buttonToColorMap = [NSMapTable strongToStrongObjectsMapTable];

	CGFloat scale = self.window ? self.window.screen.scale : [UIScreen mainScreen].scale;
	[colors enumerateObjectsUsingBlock:^(id color, NSUInteger index, BOOL *stop) {
		UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];

		[button addTarget:self action:@selector(colorSelected:) forControlEvents:UIControlEventTouchUpInside];
		[button addTarget:self action:@selector(colorSelectionStarted:) forControlEvents:UIControlEventTouchDown];

		CGFloat hue, saturation, brightness, alpha = 0.;
		[color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
		button.layer.borderWidth = (1. / scale);
		button.layer.borderColor = [UIColor colorWithHue:hue saturation:saturation * 1.13 brightness:brightness * .88 alpha:alpha].CGColor;

		[self.contentView addSubview:button];

		[_buttonToColorMap setObject:color forKey:button];
		[_colorToButtonMap setObject:button forKey:color];
	}];

	[self setNeedsLayout];
	[self layoutIfNeeded];
}

- (void) layoutSubviews {
	[super layoutSubviews];

	NSUInteger numberOfRows = floor(sqrt(self.colors.count));
	NSUInteger numberOfItemsInColumn = numberOfRows;
	NSUInteger numberOfItemsInLastRow = self.colors.count - (numberOfRows * numberOfItemsInColumn);

	CGFloat buttonMargin = 5.;
	CGFloat spaceUsedForHeightPadding = (numberOfRows + 1) * buttonMargin;
	CGFloat buttonHeight = (CGRectGetHeight(self.contentView.frame) - spaceUsedForHeightPadding) / numberOfRows;
	CGFloat spaceUsedForWidthPadding = (numberOfItemsInColumn + 1) * buttonMargin;
	CGFloat buttonWidth = (CGRectGetWidth(self.contentView.frame) - spaceUsedForWidthPadding) / numberOfItemsInColumn;
	CGFloat lastRowExtraButtonXMargin = (CGRectGetWidth(self.contentView.frame) - ((numberOfItemsInLastRow * buttonWidth) + ((numberOfItemsInLastRow + 2) * buttonMargin)));

	__block NSUInteger row = 0;
	__block NSUInteger column = 0;
	[self.colors enumerateObjectsUsingBlock:^(id object, NSUInteger index, BOOL *stop) {
		UIButton *button = [self.colorToButtonMap objectForKey:object];

		CGRect buttonRect = CGRectZero;
		buttonRect.size.width = buttonWidth;
		buttonRect.size.height = buttonHeight;
		buttonRect.origin.y = (buttonMargin * (row + 1)) + (buttonHeight * row);
		if (row == (numberOfRows - 1) && numberOfItemsInLastRow > 0)
			buttonRect.origin.x = lastRowExtraButtonXMargin + (buttonMargin * (column + 1)) + (buttonWidth * column);
		else buttonRect.origin.x = (buttonMargin * (column + 1)) + (buttonWidth * column);
		button.frame = buttonRect;

		if ([self.activeColor isEqual:object]) {
			[button setBackgroundImage:[UIImage patternImageWithColor:[object colorWithAlphaComponent:.5]] forState:UIControlStateNormal];
			[button setBackgroundImage:[UIImage patternImageWithColor:object] forState:(UIControlStateSelected | UIControlStateHighlighted)];
		} else {
			[button setBackgroundImage:[UIImage patternImageWithColor:[object colorWithAlphaComponent:.5]] forState:(UIControlStateSelected | UIControlStateHighlighted)];
			[button setBackgroundImage:[UIImage patternImageWithColor:object] forState:UIControlStateNormal];
		}

		column++;
		if (column > (numberOfItemsInColumn - 1)) {
			row++;
			column = 0;
		}
	}];
}

- (void) colorSelected:(__nullable id) sender {
	UIColor *newColor = [self.buttonToColorMap objectForKey:sender];
	self.activeColor = (newColor == self.activeColor ? nil : newColor);

	UIButton *button = (UIButton *)sender;
	button.layer.borderColor = [[UIColor colorWithCGColor:button.layer.borderColor] colorWithAlphaComponent:1.].CGColor;

	if (self.colorSelectedBlock)
		self.colorSelectedBlock(self.activeColor);
}

- (void) colorSelectionStarted:(__nullable id) sender {
	UIButton *button = (UIButton *)sender;
	button.layer.borderColor = [[UIColor colorWithCGColor:button.layer.borderColor] colorWithAlphaComponent:.5].CGColor;
}
@end

NS_ASSUME_NONNULL_END

#pragma mark -

NS_ASSUME_NONNULL_BEGIN

@implementation  CQMultiButtonTableCell : UITableViewCell
- (void) addButtonWithConfigurationHandler:(void (^)(UIButton *button)) configurationHandler {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
	button.layer.borderWidth = 1.;
	button.layer.borderColor = [UIApplication sharedApplication].keyWindow.tintColor.CGColor;

	configurationHandler(button);

	[self.contentView addSubview:button];
}

- (void) setExpands:(BOOL) expands {
	if (_expands == expands)
		return;

	_expands = expands;

	if (_expands) {
		CGRect frame = self.frame;
		frame.size.height += 1.;
		[super setFrame:frame];
	}
}

- (void) setFrame:(CGRect) frame {
	if (self.expands)
		frame.size.height += 1.;
	[super setFrame:frame];
}

- (void) layoutSubviews {
	[super layoutSubviews];

	__block CGRect buttonRect = CGRectMake(0., 0., 0., CGRectGetHeight(self.frame));
	buttonRect.size.width = ((CGRectGetWidth(self.frame)) / self.contentView.subviews.count) + 1.;

	[self.contentView.subviews enumerateObjectsUsingBlock:^(id object, NSUInteger index, BOOL *stop) {
		buttonRect.origin.x = (index * CGRectGetWidth(buttonRect));
		buttonRect.origin.x -= (index + 1.);
		if (index == (self.contentView.subviews.count - 1))
			buttonRect.size.width += 1.;
		[object setFrame:buttonRect];
	}];
}

- (void) prepareForReuse {
	[super prepareForReuse];

	[self.contentView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
}
@end

NS_ASSUME_NONNULL_END
