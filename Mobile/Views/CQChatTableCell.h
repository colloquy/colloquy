@protocol CQChatViewController;

@interface CQChatTableCell : UITableViewCell {
	UIImageView *_iconImageView;
	UILabel *_nameLabel;
	NSString *_removeConfirmationText;
}
- (void) takeValuesFromChatViewController:(id <CQChatViewController>) controller;

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) UIImage *icon;

@property (nonatomic, copy) NSString *removeConfirmationText;
@end
