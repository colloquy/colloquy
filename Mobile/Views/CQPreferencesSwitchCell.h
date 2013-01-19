typedef void (^UISwitchControlBlock)(UISwitch *switchControl);

@interface CQPreferencesSwitchCell : UITableViewCell {
	@protected
	UISwitch *_switchControl;
	UISwitchControlBlock _switchControlBlock;
}
@property (nonatomic, getter=isOn) BOOL on;

@property (nonatomic, readonly) UISwitch *switchControl;

@property (nonatomic) SEL switchAction;

@property (nonatomic, copy) UISwitchControlBlock switchControlBlock;
@end
