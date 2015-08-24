@class MVChatUser;
@protocol CQChatViewController;

NS_ASSUME_NONNULL_BEGIN

@interface CQChatTableCell : UITableViewCell
- (void) takeValuesFromChatViewController:(id <CQChatViewController>) controller;

@property (nonatomic, copy) NSString *name;
@property (nonatomic, nullable, copy) UIImage *icon;
@property (nonatomic) BOOL available;
@property (nonatomic) NSUInteger unreadCount;
@property (nonatomic) NSUInteger importantUnreadCount;
@property (nonatomic) NSUInteger maximumMessagePreviews;
@property (nonatomic) BOOL showsUserInMessagePreviews;
@property (nonatomic) BOOL showsIcon;

- (void) addMessagePreview:(NSString *) message fromUser:(MVChatUser *) user asAction:(BOOL) action animated:(BOOL) animated;

- (void) layoutSubviewsWithAnimation:(BOOL) animated withDelay:(NSTimeInterval) animationDelay;
@end

NS_ASSUME_NONNULL_END
