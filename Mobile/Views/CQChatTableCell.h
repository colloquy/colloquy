@class MVChatUser;
@protocol CQChatViewController;

@interface CQChatTableCell : UITableViewCell {
	UIImageView *_iconImageView;
	UILabel *_nameLabel;
	NSString *_removeConfirmationText;
	NSMutableArray *_chatPreviewLabels;
	NSUInteger _maximumMessagePreviews;
}
- (void) takeValuesFromChatViewController:(id <CQChatViewController>) controller;

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) UIImage *icon;

@property (nonatomic, copy) NSString *removeConfirmationText;
@property (nonatomic) NSUInteger maximumMessagePreviews;

- (void) addMessagePreview:(NSString *) message fromUser:(MVChatUser *) user asAction:(BOOL) action animated:(BOOL) animated;
@end
