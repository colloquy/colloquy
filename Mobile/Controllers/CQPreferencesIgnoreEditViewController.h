#import "CQPreferencesListEditViewController.h"

@class MVChatConnection;
@class KAIgnoreRule;

NS_ASSUME_NONNULL_BEGIN

@interface CQPreferencesIgnoreEditViewController : CQPreferencesListEditViewController
- (instancetype) initWithNibName:(NSString *__nullable) nibNameOrNil bundle:(NSBundle *__nullable) nibBundleOrNil NS_UNAVAILABLE;
- (instancetype) initWithStyle:(UITableViewStyle) style NS_UNAVAILABLE;
- (__nullable instancetype) initWithCoder:(NSCoder *) aDecoder NS_UNAVAILABLE;

- (instancetype) initWithConnection:(MVChatConnection *) connection NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) KAIgnoreRule *representedRule;
@end

NS_ASSUME_NONNULL_END
