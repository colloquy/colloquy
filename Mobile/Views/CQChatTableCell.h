@protocol CQChatViewController;

@interface CQChatTableCell : UITableViewCell {
	UIImageView *_iconImageView;
	UILabel *_nameLabel;
//	UILabel *_firstChatLine;
//	UILabel *_secondChatLine;
}
- (void) takeValuesFromChatViewController:(id <CQChatViewController>) controller;

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) UIImage *icon;

//@property(copy, nonatomic) NSString *firstChatLineText;
//@property(copy, nonatomic) NSString *secondChatLineText;
@end
