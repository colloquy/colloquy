#import "CQPreferencesDeleteCell.h"

NS_ASSUME_NONNULL_BEGIN

@implementation CQPreferencesDeleteCell

- (instancetype) initWithStyle:(UITableViewCellStyle) style reuseIdentifier:(NSString *__nullable) reuseIdentifier {
	if (!(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
		return nil;

	self.selectionStyle = UITableViewCellSelectionStyleNone;

	_deleteButton = [UIButton buttonWithType:UIButtonTypeCustom];

	_deleteButton.frame = self.contentView.bounds;
	_deleteButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;

	[self.contentView addSubview:_deleteButton];

	_deleteButton.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
	_deleteButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
	_deleteButton.backgroundColor = [UIColor whiteColor];
	[_deleteButton setTitleColor:[UIColor colorWithRed:(223. / 255.) green:(59. / 255.) blue:(42. / 255.) alpha:1.] forState:UIControlStateNormal];
	[_deleteButton setTitle:NSLocalizedString(@"Delete", @"Delete button title") forState:UIControlStateNormal];

	return self;
}

- (UIView *__nullable) backgroundView {
	return nil;
}

- (UIView *__nullable) selectedBackgroundView {
	return nil;
}

- (SEL __nullable) deleteAction {
	NSArray <NSString *> *actions = [_deleteButton actionsForTarget:nil forControlEvent:UIControlEventTouchUpInside];
	if (!actions.count) return NULL;
	return NSSelectorFromString(actions[0]);
}

- (void) setDeleteAction:(SEL __nullable) action {
	[_deleteButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
	[_deleteButton addTarget:nil action:action forControlEvents:UIControlEventTouchUpInside];
}
@end

NS_ASSUME_NONNULL_END
