#define UserActionSheetTag 1
#define OperatorActionSheetTag 2

@class MVChatUser;
@class MVChatRoom;

@interface UIActionSheet (Additions)
+ (UIActionSheet *) userActionSheetForUser:(MVChatUser *) user inRoom:(MVChatRoom *) room showingUserInformation:(BOOL) showingUserInformation;
+ (UIActionSheet *) operatorActionSheetWithLocalUserModes:(NSUInteger) localUserModes targetingUserWithModes:(NSUInteger) selectedUserModes disciplineModes:(NSUInteger) disciplineModes onRoomWithFeatures:(NSSet *) features;
@end
