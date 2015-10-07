#import "CQPreferencesTableViewController.h"

@class MVChatConnection;

NS_ASSUME_NONNULL_BEGIN

@interface CQConnectionAdvancedEditController : CQPreferencesTableViewController {
	@protected
	MVChatConnection *_connection;
	BOOL _newConnection;
}
@property (nonatomic, strong) MVChatConnection *connection;
@property (nonatomic, getter=isNewConnection) BOOL newConnection;
@end

NS_ASSUME_NONNULL_END
