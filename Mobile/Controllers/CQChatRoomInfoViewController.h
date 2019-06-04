#import "CQModalNavigationController.h"
#import "CQChatRoomInfoDisplayViewController.h"

@class MVChatRoom;

NS_ASSUME_NONNULL_BEGIN

@interface CQChatRoomInfoViewController : CQModalNavigationController

- (nonnull instancetype)initWithNavigationBarClass:(nullable Class)navigationBarClass toolbarClass:(nullable Class)toolbarClass NS_UNAVAILABLE;
- (nonnull instancetype)initWithRootViewController:(UIViewController *)rootViewController NS_UNAVAILABLE;
- (nonnull instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;

- (nonnull instancetype) initWithRoom:(nonnull MVChatRoom *) room showingInfoType:(CQChatRoomInfo) infoType NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
