@class CQActionSheet;

NS_ASSUME_NONNULL_BEGIN

@protocol CQActionSheetDelegate <NSObject>
@optional
- (void) actionSheet:(CQActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex;
@end

@interface CQActionSheet : NSObject
@property NSInteger tag;

@property (nullable, weak) id <CQActionSheetDelegate> delegate;
@property (copy) NSString *title;

@property NSInteger cancelButtonIndex;
@property NSInteger destructiveButtonIndex;

- (NSInteger) addButtonWithTitle:(nullable NSString *) title;
- (nullable NSString *) buttonTitleAtIndex:(NSInteger) buttonIndex;

- (void) showforSender:(__nullable id) sender orFromPoint:(CGPoint) point animated:(BOOL) animated;
@end

#pragma mark -

#define UserActionSheetTag 1
#define OperatorActionSheetTag 2

@class MVChatUser;
@class MVChatRoom;

@interface CQActionSheet (Additions)
+ (CQActionSheet *) userActionSheetForUser:(MVChatUser *) user inRoom:(MVChatRoom *) room showingUserInformation:(BOOL) showingUserInformation;
+ (CQActionSheet *) operatorActionSheetWithLocalUserModes:(NSUInteger) localUserModes targetingUserWithModes:(NSUInteger) selectedUserModes disciplineModes:(NSUInteger) disciplineModes onRoomWithFeatures:(NSSet *) features;
@end

NS_ASSUME_NONNULL_END
