#import "CQPreferencesListEditViewController.h"

@class MVChatConnection;

@interface CQPreferencesListChannelEditViewController : CQPreferencesListEditViewController {
	MVChatConnection *_connection;
	NSString *_password;
}
@property (nonatomic, retain) MVChatConnection *connection;
@end
