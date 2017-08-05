NS_ASSUME_NONNULL_BEGIN

typedef void (^UISwitchControlBlock)(UISwitch *switchControl);

@interface CQPreferencesSwitchCell : UITableViewCell
@property (nonatomic, getter=isOn) BOOL on;

@property (nonatomic, readonly) UISwitch *switchControl;

@property (nonatomic, nullable) SEL switchAction;

@property (nonatomic, copy) UISwitchControlBlock switchControlBlock;
@end

NS_ASSUME_NONNULL_END
