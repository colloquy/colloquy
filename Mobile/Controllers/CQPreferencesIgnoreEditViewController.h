#import "CQPreferencesListEditViewController.h"

@class MVChatConnection;
@class KAIgnoreRule;

@interface CQPreferencesIgnoreEditViewController : CQPreferencesListEditViewController {
@private
	MVChatConnection *_connection;
	KAIgnoreRule *__weak _representedRule;
}

- (instancetype) initWithConnection:(MVChatConnection *) connection NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) KAIgnoreRule *representedRule;
@end
