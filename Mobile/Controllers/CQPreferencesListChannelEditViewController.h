#import "CQPreferencesListEditViewController.h"

@class MVChatConnection;

@interface CQPreferencesListChannelEditViewController : CQPreferencesListEditViewController {
	MVChatConnection *_connection;
}
@property (nonatomic, retain) MVChatConnection *connection;
@end
