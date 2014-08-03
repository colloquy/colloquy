#import "CQTableViewController.h"

@implementation CQTableViewController
- (id) initWithStyle:(UITableViewStyle) style {
	return (self = [super initWithStyle:style]);
}

- (void) dealloc {
	if ([self isViewLoaded]) {
		self.tableView.dataSource = nil;
		self.tableView.delegate = nil;
	}

	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];
	[self.tableView performSelectorOnMainThread:@selector(hideEmptyCells) withObject:nil waitUntilDone:YES];
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_reloadTableView) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
}

#pragma mark -

- (void) _reloadTableView {
	if ([self isViewLoaded])
		[self.tableView reloadData];
}
@end
