#import "CQChatController.h"

@class MVChatConnection;
@class CQChatListViewController;

@interface CQChatNavigationController : UINavigationController {
	CQChatListViewController *_chatListViewController;
	BOOL _active;
}
@end
