#import "CQModalNavigationController.h"

@class MVChatConnection;

NS_ASSUME_NONNULL_BEGIN

@interface CQChatCreationViewController : CQModalNavigationController
@property (nonatomic, getter=isRoomTarget) BOOL roomTarget;
@property (nonatomic, strong) MVChatConnection *selectedConnection;

- (void) showRoomListFilteredWithSearchString:(NSString *) searchString;
@end

NS_ASSUME_NONNULL_END
