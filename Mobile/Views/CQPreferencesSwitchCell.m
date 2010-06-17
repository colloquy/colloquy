#import "CQPreferencesSwitchCell.h"

@implementation CQPreferencesSwitchCell
- (id) initWithStyle:(UITableViewCellStyle) style reuseIdentifier:(NSString *) reuseIdentifier {
	if (!(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
		return nil;

	self.selectionStyle = UITableViewCellSelectionStyleNone;

	_switchControl = [[UISwitch alloc] initWithFrame:CGRectZero];

	[self.contentView addSubview:_switchControl];

	return self;
}

- (void) dealloc {
	[_switchControl release];

	[super dealloc];
}

#pragma mark -

@synthesize switchControl = _switchControl;

- (SEL) switchAction {
	NSArray *actions = [_switchControl actionsForTarget:nil forControlEvent:UIControlEventValueChanged];
	if (!actions.count) return NULL;
	return NSSelectorFromString([actions objectAtIndex:0]);
}

- (void) setSwitchAction:(SEL) action {
	[_switchControl removeTarget:nil action:NULL forControlEvents:UIControlEventValueChanged];
	[_switchControl addTarget:nil action:action forControlEvents:UIControlEventValueChanged];
}

- (BOOL) isOn {
	return _switchControl.on;
}

- (void) setOn:(BOOL) on {
	_switchControl.on = on;
}

- (void) prepareForReuse {
	[super prepareForReuse];

	self.textLabel.text = @"";
	self.on = NO;
}

- (void) layoutSubviews {
	[super layoutSubviews];

	CGSize switchSize = _switchControl.frame.size;
	CGRect contentRect = self.contentView.frame;

	UILabel *label = self.textLabel;

	CGRect frame = label.frame;
	frame.size.width = contentRect.size.width - switchSize.width - 30.;
	label.frame = frame;

	frame = _switchControl.frame;
	frame.origin.y = round((contentRect.size.height / 2.) - (switchSize.height / 2.));
	frame.origin.x = contentRect.size.width - switchSize.width - 10.;
	_switchControl.frame = frame;
}
@end
