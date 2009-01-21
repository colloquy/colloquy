#import "CQPreferencesSwitchCell.h"

@implementation CQPreferencesSwitchCell
- (id) initWithFrame:(CGRect) frame reuseIdentifier:(NSString *) reuseIdentifier {
	if (!(self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier]))
		return nil;

	self.selectionStyle = UITableViewCellSelectionStyleNone;
	self.backgroundColor = nil;
	self.opaque = NO;

	_switchControl = [[UISwitch alloc] initWithFrame:CGRectZero];
	_label = [[UILabel alloc] initWithFrame:CGRectZero];

	_label.font = [UIFont boldSystemFontOfSize:17.];
	_label.textColor = self.textColor;
	_label.highlightedTextColor = self.selectedTextColor;
	_label.backgroundColor = nil;
	_label.opaque = NO;

	[self.contentView addSubview:_label];
	[self.contentView addSubview:_switchControl];

	return self;
}

- (void) dealloc {
	[_switchControl release];
	[_label release];

	[super dealloc];
}

@synthesize switchControl = _switchControl;

- (SEL) switchAction {
	NSArray *actions = [_switchControl actionsForTarget:self.target forControlEvent:UIControlEventValueChanged];
	if (!actions.count) return NULL;
	return NSSelectorFromString([actions objectAtIndex:0]);
}

- (void) setSwitchAction:(SEL) action {
	[_switchControl removeTarget:self.target action:NULL forControlEvents:UIControlEventValueChanged];
	[_switchControl addTarget:self.target action:action forControlEvents:UIControlEventValueChanged];
}

- (NSString *) label {
	return _label.text;
}

- (void) setLabel:(NSString *) labelText {
	_label.text = labelText;
}

- (BOOL) isOn {
	return _switchControl.on;
}

- (void) setOn:(BOOL) on {
	_switchControl.on = on;
}

- (void) prepareForReuse {
	[super prepareForReuse];

	self.label = @"";
	self.on = NO;
}

- (void) layoutSubviews {
	[super layoutSubviews];

	CGSize switchSize = _switchControl.frame.size;
	CGRect contentRect = self.contentView.frame;

	CGRect frame = _label.frame;
	frame.size = [_label sizeThatFits:_label.bounds.size];
	frame.origin.x = 10.;
	frame.origin.y = round((contentRect.size.height / 2.) - (frame.size.height / 2.));
	frame.size.width = contentRect.size.width - switchSize.width - 30.;
	_label.frame = frame;

	frame = _switchControl.frame;
	frame.origin.y = round((contentRect.size.height / 2.) - (switchSize.height / 2.));
	frame.origin.x = contentRect.size.width - switchSize.width - 10.;
	_switchControl.frame = frame;
}
@end
