#import "CQPreferencesDeleteCell.h"

@implementation CQPreferencesDeleteCell

- (id) initWithStyle:(UITableViewCellStyle) style reuseIdentifier:(NSString *) reuseIdentifier {
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

- (UIView *) backgroundView {
	return nil;
}

- (UIView *) selectedBackgroundView {
	return nil;
}

- (SEL) deleteAction {
	NSArray *actions = [_deleteButton actionsForTarget:nil forControlEvent:UIControlEventTouchUpInside];
	if (!actions.count) return NULL;
	return NSSelectorFromString(actions[0]);
}

- (void) setDeleteAction:(SEL) action {
	[_deleteButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
	[_deleteButton addTarget:nil action:action forControlEvents:UIControlEventTouchUpInside];
}
@end
