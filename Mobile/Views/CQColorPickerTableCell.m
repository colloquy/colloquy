#import "CQColorPickerTableCell.h"

#import "UIImageAdditions.h"

@interface CQColorPickerTableCell ()
@property (atomic, strong) NSMapTable *colorToButtonMap;
@property (atomic, strong) NSMapTable *buttonToColorMap;
@end

@implementation CQColorPickerTableCell
- (id) initWithStyle:(UITableViewCellStyle) style reuseIdentifier:(NSString *) reuseIdentifier {
	if (!(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
		return nil;

	self.selectionStyle = UITableViewCellSelectionStyleNone;
	self.selectedBackgroundView = [[UIView alloc] initWithFrame:CGRectZero];

	return self;
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

		[button setBackgroundImage:[UIImage patternImageWithColor:color] forState:UIControlStateNormal];
		[button setBackgroundImage:[UIImage patternImageWithColor:[color colorWithAlphaComponent:.5]] forState:(UIControlStateSelected | UIControlStateHighlighted)];

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

		if (self.activeColor == object) {
			[button setBackgroundImage:[UIImage patternImageWithColor:[object colorWithAlphaComponent:.5]] forState:UIControlStateNormal];
			[button setBackgroundImage:[UIImage patternImageWithColor:object] forState:(UIControlStateSelected | UIControlStateHighlighted)];
		}

		column++;
		if (column > (numberOfItemsInColumn - 1)) {
			row++;
			column = 0;
		}
	}];
}

- (void) colorSelected:(id) sender {
	UIButton *button = (UIButton *)sender;
	button.layer.borderColor = [[UIColor colorWithCGColor:button.layer.borderColor] colorWithAlphaComponent:1.].CGColor;

	if (self.colorSelectedBlock)
		self.colorSelectedBlock([self.buttonToColorMap objectForKey:sender]);
}

- (void) colorSelectionStarted:(id) sender {
	UIButton *button = (UIButton *)sender;
	button.layer.borderColor = [[UIColor colorWithCGColor:button.layer.borderColor] colorWithAlphaComponent:.5].CGColor;
}
@end

#pragma mark -

@implementation CQMultiButtonTableCell : UITableViewCell
- (void) addButtonWithConfigurationHandler:(void (^)(UIButton *button)) configurationHandler {
	UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
	button.layer.borderWidth = 1.;
	button.layer.borderColor = [UIApplication sharedApplication].keyWindow.tintColor.CGColor;

	configurationHandler(button);

	[self.contentView addSubview:button];
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
