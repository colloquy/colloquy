#define UserActionSheetTag 1
#define OperatorActionSheetTag 2

@class MVChatUser;
@class MVChatRoom;

NS_ASSUME_NONNULL_BEGIN

@interface UIActionSheet (Additions)
+ (UIActionSheet *) userActionSheetForUser:(MVChatUser *) user inRoom:(MVChatRoom *) room showingUserInformation:(BOOL) showingUserInformation;
+ (UIActionSheet *) operatorActionSheetWithLocalUserModes:(NSUInteger) localUserModes targetingUserWithModes:(NSUInteger) selectedUserModes disciplineModes:(NSUInteger) disciplineModes onRoomWithFeatures:(NSSet *) features;
@end

NS_ASSUME_NONNULL_END
