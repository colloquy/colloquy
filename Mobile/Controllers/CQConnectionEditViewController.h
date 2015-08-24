#import "CQPreferencesTableViewController.h"

@class MVChatConnection;

NS_ASSUME_NONNULL_BEGIN

@interface CQConnectionEditViewController : CQPreferencesTableViewController
@property (nonatomic, strong) MVChatConnection *connection;
@property (nonatomic, getter=isNewConnection) BOOL newConnection;
@end

NS_ASSUME_NONNULL_END
