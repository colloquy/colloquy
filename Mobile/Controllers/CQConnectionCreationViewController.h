#import "CQModalNavigationController.h"

@class MVChatConnection;

NS_ASSUME_NONNULL_BEGIN

@interface CQConnectionCreationViewController : CQModalNavigationController <UINavigationControllerDelegate> {
	@protected
	MVChatConnection *_connection;
}
@property (nonatomic, nullable, copy) NSURL *url;
@end

NS_ASSUME_NONNULL_END
