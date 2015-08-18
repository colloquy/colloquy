NS_ASSUME_NONNULL_BEGIN

@interface CQTableViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
- (instancetype)initWithStyle:(UITableViewStyle)style NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;

@property (nonatomic, strong, readonly) UITableView *tableView;
@property (nonatomic) BOOL clearsSelectionOnViewWillAppear; // defaults to YES. If YES, any selection is cleared in viewWillAppear:
@end

NS_ASSUME_NONNULL_END
