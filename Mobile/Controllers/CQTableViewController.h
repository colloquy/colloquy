NS_ASSUME_NONNULL_BEGIN

@interface CQTableViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
- (instancetype)initWithStyle:(UITableViewStyle)style NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(NSString *__nullable)nibNameOrNil bundle:(NSBundle *__nullable)nibBundleOrNil NS_DESIGNATED_INITIALIZER;
- (__nullable instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;

@property (nonatomic, strong, readonly) UITableView *tableView;
@property (nonatomic) BOOL clearsSelectionOnViewWillAppear; // defaults to YES. If YES, any selection is cleared in viewWillAppear:
@end

NS_ASSUME_NONNULL_END
