@interface CQPreferencesSwitchCell : UITableViewCell {
	@protected
	UISwitch *_switchControl;
}
@property (nonatomic, getter=isOn) BOOL on;

@property (nonatomic, readonly) UISwitch *switchControl;

@property (nonatomic) SEL switchAction;
@end
