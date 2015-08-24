#import "CQTableViewController.h"

#import "UITableViewAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation  CQTableViewController {
	UITableViewStyle _style;
	UITableView *_tableView;
}

- (instancetype)initWithStyle:(UITableViewStyle)style {
	if (!(self = [super initWithNibName:nil bundle:nil]))
		return nil;

	_style = style;
	_clearsSelectionOnViewWillAppear = YES;

	return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
		return nil;

	_style = UITableViewStylePlain;
	_clearsSelectionOnViewWillAppear = YES;

	return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
	if (!(self = [super initWithCoder:aDecoder]))
		return nil;

	_style = UITableViewStylePlain;
	_clearsSelectionOnViewWillAppear = YES;

	return self;
}

- (void) loadView {
	UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:_style];
	tableView.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin);
	tableView.dataSource = self;
	tableView.delegate = self;

	[tableView hideEmptyCells];

	self.view = tableView;
}

- (UITableView *)tableView {
	return (UITableView *)self.view;
}

- (void) dealloc {
	if ([self isViewLoaded]) {
		_tableView.dataSource = nil;
		_tableView.delegate = nil;
	}

	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];
	[_tableView performSelectorOnMainThread:@selector(hideEmptyCells) withObject:nil waitUntilDone:YES];
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_reloadTableView) name:UIApplicationWillEnterForegroundNotification object:nil];

	if (_clearsSelectionOnViewWillAppear) {
		for (NSIndexPath *indexPath in _tableView.indexPathsForSelectedRows)
			[_tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
}

#pragma mark -

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSAssert(NO, @"tableView:numberOfRowsInSection: not implemented");
	return 0;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	NSAssert(NO, @"tableView:cellForRowAtIndexPath: not implemented");
	return nil;
}

#pragma mark -

- (void) _reloadTableView {
	if ([self isViewLoaded])
		[_tableView reloadData];
}
@end

NS_ASSUME_NONNULL_END
