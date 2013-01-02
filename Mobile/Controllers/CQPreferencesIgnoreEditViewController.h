#import "CQPreferencesListEditViewController.h"

@class MVChatConnection;
@class KAIgnoreRule;

@interface CQPreferencesIgnoreEditViewController : CQPreferencesListEditViewController {
@private
	MVChatConnection *_connection;
	KAIgnoreRule *_representedRule;
}

- (id) initWithConnection:(MVChatConnection *) connection;

@property (nonatomic, readonly) KAIgnoreRule *representedRule;
@end
