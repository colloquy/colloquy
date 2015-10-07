NS_ASSUME_NONNULL_BEGIN

@interface CQPreferencesDeleteCell : UITableViewCell {
	@protected
	UIButton *_deleteButton;
}
@property (nonatomic) SEL deleteAction;

@property (nonatomic, readonly) UIButton *deleteButton;
@end

NS_ASSUME_NONNULL_END
