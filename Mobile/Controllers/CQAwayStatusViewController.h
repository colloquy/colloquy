#import "CQPreferencesTextEditViewController.h"
#import "CQPreferencesListViewController.h"

@class MVChatConnection;

NS_ASSUME_NONNULL_BEGIN

@interface CQAwayStatusViewController : CQPreferencesListViewController
@property (nonatomic, strong) MVChatConnection *connection;
@end

NS_ASSUME_NONNULL_END
