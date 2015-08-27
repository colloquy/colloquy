#import "UITableViewCellAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation UITableViewCell (UITableViewCellColloquyAdditions)
+ (id) reusableTableViewCellInTableView:(UITableView *) tableView {
	return [self reusableTableViewCellInTableView:tableView withIdentifier:NSStringFromClass([self class])];
}

+ (id) reusableTableViewCellWithStyle:(UITableViewCellStyle) style inTableView:(UITableView *) tableView {
	NSString *identifierFormat = nil;

	switch (style) {
	case UITableViewCellStyleDefault:
		identifierFormat = @"%@:UITableViewCellStyleDefault";
		break;
	case UITableViewCellStyleValue1:
		identifierFormat = @"%@:UITableViewCellStyleValue1";
		break;
	case UITableViewCellStyleValue2:
		identifierFormat = @"%@:UITableViewCellStyleValue2";
		break;
	case UITableViewCellStyleSubtitle:
		identifierFormat = @"%@:UITableViewCellStyleSubtitle";
		break;
	}

	NSString *identifier = [[NSString alloc] initWithFormat:identifierFormat, NSStringFromClass([self class])];
	id cell = [self reusableTableViewCellWithStyle:style inTableView:tableView withIdentifier:identifier];

	return cell;
}

+ (id) reusableTableViewCellInTableView:(UITableView *) tableView withIdentifier:(NSString *) identifier {
	return [self reusableTableViewCellWithStyle:UITableViewCellStyleDefault inTableView:tableView withIdentifier:identifier];
}

+ (id) reusableTableViewCellWithStyle:(UITableViewCellStyle) style inTableView:(UITableView *) tableView withIdentifier:(NSString *) identifier {
	id cell = [tableView dequeueReusableCellWithIdentifier:identifier];
	if (cell) return cell;

	return [[[self class] alloc] initWithStyle:style reuseIdentifier:identifier];
}

#pragma mark -

- (void) performAction:(SEL) action sender:(__nullable id) sender {
	UITableView *tableView = (UITableView *)self.superview;
	if (![tableView isKindOfClass:[UITableView class]])
		return;

	[tableView performAction:action forCell:self sender:sender];
}

#pragma mark -

- (void) join:(__nullable id) sender {
	[self performAction:_cmd sender:sender];
}

- (void) leave:(__nullable id) sender {
	[self performAction:_cmd sender:sender];
}

- (void) connect:(__nullable id) sender {
	[self performAction:_cmd sender:sender];
}

- (void) disconnect:(__nullable id) sender {
	[self performAction:_cmd sender:sender];
}

@end

NS_ASSUME_NONNULL_END
