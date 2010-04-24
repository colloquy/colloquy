#import "CQModalNavigationController.h"

@class MVChatConnection;

@interface CQConnectionCreationViewController : CQModalNavigationController <UINavigationControllerDelegate> {
	@protected
	MVChatConnection *_connection;
}
@property (nonatomic, copy) NSURL *url;
@end
