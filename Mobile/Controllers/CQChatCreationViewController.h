#import "CQModalNavigationController.h"

@class MVChatConnection;

@interface CQChatCreationViewController : CQModalNavigationController <UINavigationControllerDelegate> {
	@protected
	BOOL _roomTarget;
	MVChatConnection *_selectedConnection;
	NSString *_name;
	NSString *_password;
	BOOL _showListOnLoad;
	NSString *_searchString;
}
@property (nonatomic, getter=isRoomTarget) BOOL roomTarget;
@property (nonatomic, retain) MVChatConnection *selectedConnection;

- (void) showRoomListFilteredWithSearchString:(NSString *) searchString;
@end
