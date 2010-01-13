@interface CQPreferencesDeleteCell : UITableViewCell {
	@protected
	UIButton *_deleteButton;
}
@property (nonatomic) SEL deleteAction;

@property (nonatomic, readonly) UIButton *deleteButton;
@end
