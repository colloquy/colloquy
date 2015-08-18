NS_ASSUME_NONNULL_BEGIN

@interface CQChatRoomInfoTableCell : UITableViewCell {
	@protected
	UIImageView *_iconImageView;
	UILabel *_nameLabel;
	UILabel *_topicLabel;
	UILabel *_memberCountLabel;
	UIImageView *_memberIconImageView;
	UIImageView *_checkmarkImageView;
}
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *topic;
@property (nonatomic) NSUInteger memberCount;
@end

NS_ASSUME_NONNULL_END
