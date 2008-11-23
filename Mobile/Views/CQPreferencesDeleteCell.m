#import "CQPreferencesDeleteCell.h"

@implementation CQPreferencesDeleteCell

- (id) initWithFrame:(CGRect) frame reuseIdentifier:(NSString *) reuseIdentifier {
	if (!(self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier]))
		return nil;

	_deleteButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];

	_deleteButton.frame = self.contentView.bounds;
	_deleteButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;

	[self.contentView addSubview:_deleteButton];

	_deleteButton.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
	_deleteButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
	_deleteButton.font = [UIFont boldSystemFontOfSize:20.];
	_deleteButton.titleShadowOffset = CGSizeMake(0., -1.);

	[_deleteButton setTitleShadowColor:[UIColor colorWithWhite:0. alpha:(1. / 3.)] forState:UIControlStateNormal];

	[_deleteButton setTitle:NSLocalizedString(@"Delete", @"Delete button title") forState:UIControlStateNormal];

	UIImage *_deleteButtonImage = [[UIImage imageNamed:@"deleteButtonNormal.png"] stretchableImageWithLeftCapWidth:6. topCapHeight:0.];
	[_deleteButton setBackgroundImage:_deleteButtonImage forState:UIControlStateNormal];

	_deleteButtonImage = [[UIImage imageNamed:@"deleteButtonPressed.png"] stretchableImageWithLeftCapWidth:6. topCapHeight:0.];
	[_deleteButton setBackgroundImage:_deleteButtonImage forState:UIControlStateHighlighted];

	return self;
}

- (void) dealloc {
	[_deleteButton release];
	[super dealloc];
}

- (UIView *) backgroundView {
	return nil;
}

- (UIView *) selectedBackgroundView {
	return nil;
}

- (NSString *) text {
	return [_deleteButton titleForState:UIControlStateNormal];
}

- (void) setText:(NSString *) text {
	[_deleteButton setTitle:text forState:UIControlStateNormal];
}

- (SEL) deleteAction {
	NSArray *actions = [_deleteButton actionsForTarget:self.target forControlEvent:UIControlEventTouchUpInside];
	if (!actions.count) return NULL;
	return NSSelectorFromString([actions objectAtIndex:0]);
}

- (void) setDeleteAction:(SEL) action {
	[_deleteButton removeTarget:self.target action:NULL forControlEvents:UIControlEventTouchUpInside];
	[_deleteButton addTarget:self.target action:action forControlEvents:UIControlEventTouchUpInside];
}
@end
