#import "CQPreferencesListEditViewController.h"

@class MVChatConnection;

NS_ASSUME_NONNULL_BEGIN

@interface CQPreferencesListChannelEditViewController : CQPreferencesListEditViewController {
	MVChatConnection *_connection;
	NSString *_password;
}
@property (nonatomic, strong) MVChatConnection *connection;
@end

NS_ASSUME_NONNULL_END
