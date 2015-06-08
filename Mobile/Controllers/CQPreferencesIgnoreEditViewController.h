#import "CQPreferencesListEditViewController.h"

@class MVChatConnection;
@class KAIgnoreRule;

@interface CQPreferencesIgnoreEditViewController : CQPreferencesListEditViewController {
@private
	MVChatConnection *_connection;
	KAIgnoreRule *_representedRule;
}

- (instancetype) initWithNibName:(NSString *) nibNameOrNil bundle:(NSBundle *) nibBundleOrNil NS_UNAVAILABLE;
- (instancetype) initWithStyle:(UITableViewStyle) style NS_UNAVAILABLE;
- (instancetype) initWithCoder:(NSCoder *) aDecoder NS_UNAVAILABLE;

- (instancetype) initWithConnection:(MVChatConnection *) connection NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) KAIgnoreRule *representedRule;
@end
