@class MVChatUser;
@class CQUnreadCountView;
@protocol CQChatViewController;

#if defined(ENABLE_SECRETS) && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_0
@class UIRemoveControl;
#endif

@interface CQChatTableCell : UITableViewCell {
	@protected
	UIImageView *_iconImageView;
	UILabel *_nameLabel;
	CQUnreadCountView *_unreadCountView;
	NSMutableArray *_chatPreviewLabels;
#if defined(ENABLE_SECRETS) && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_0
	UIRemoveControl *_removeControl;
	NSString *_removeConfirmationText;
#endif
	NSUInteger _maximumMessagePreviews;
	BOOL _showsUserInMessagePreviews;
	BOOL _available;
	BOOL _animating;
}
- (void) takeValuesFromChatViewController:(id <CQChatViewController>) controller;

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) UIImage *icon;
@property (nonatomic) BOOL available;
@property (nonatomic) NSUInteger unreadCount;
@property (nonatomic) NSUInteger importantUnreadCount;

#if defined(ENABLE_SECRETS) && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_0
@property (nonatomic, copy) NSString *removeConfirmationText;
#endif

@property (nonatomic) NSUInteger maximumMessagePreviews;
@property (nonatomic) BOOL showsUserInMessagePreviews;
@property (nonatomic) BOOL showsIcon;

- (void) addMessagePreview:(NSString *) message fromUser:(MVChatUser *) user asAction:(BOOL) action animated:(BOOL) animated;

- (void) layoutSubviewsWithAnimation:(BOOL) animated withDelay:(NSTimeInterval) animationDelay;
@end
