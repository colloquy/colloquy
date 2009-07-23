@interface CQChatRoomInfoTableCell : UITableViewCell {
	@protected
	UIImageView *_iconImageView;
	UILabel *_nameLabel;
	UILabel *_topicLabel;
	UILabel *_memberCountLabel;
	UIImageView *_memberIconImageView;
}
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *topic;
@property (nonatomic) NSUInteger memberCount;
@end
