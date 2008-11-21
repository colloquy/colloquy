@interface CQPreferencesSwitchCell : UITableViewCell {
	UILabel *_label;
	UISwitch *_switchControl;
}
@property (nonatomic, copy) NSString *label;
@property (nonatomic, getter=isOn) BOOL on;

@property (nonatomic, readonly) UISwitch *switchControl;
@end
