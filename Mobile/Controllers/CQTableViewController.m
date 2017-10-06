#import "CQTableViewController.h"

#import "UITableViewAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@interface CQTableViewController () <UITableViewDelegate, UITableViewDataSource>
@end

@implementation CQTableViewController {
	UITableViewStyle _style;
	UITableView *_tableView;
	UIEdgeInsets _insetsPriorToKeyboardAppearance;
}

- (instancetype)initWithStyle:(UITableViewStyle)style {
	if (!(self = [super initWithNibName:nil bundle:nil]))
		return nil;

	_style = style;
	_clearsSelectionOnViewWillAppear = YES;

	return self;
}

- (instancetype)initWithNibName:(NSString *__nullable)nibNameOrNil bundle:(NSBundle *__nullable)nibBundleOrNil {
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

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(CQTableViewController_keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(CQTableViewController_keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

#pragma mark -

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSAssert(NO, @"tableView:numberOfRowsInSection: not implemented");
	[self doesNotRecognizeSelector:_cmd];
	__builtin_unreachable();
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	NSAssert(NO, @"tableView:cellForRowAtIndexPath: not implemented");
	[self doesNotRecognizeSelector:_cmd];
	__builtin_unreachable();
}

#pragma mark -

- (void) CQTableViewController_keyboardWillShow:(NSNotification *) notification {
	_insetsPriorToKeyboardAppearance = self.tableView.contentInset;

	CGRect keyboardRect = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
	keyboardRect = [self.view.window convertRect:keyboardRect toView:self.view];

	NSTimeInterval animationDuration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
	NSUInteger animationCurve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue];

	if (CGRectIntersectsRect(keyboardRect, self.tableView.frame)) {
		[UIView animateWithDuration:(animationDuration) delay:.0 options:animationCurve animations:^{
			CGRect intersection = CGRectIntersection(keyboardRect, self.tableView.frame);
			UIEdgeInsets insets = self.tableView.contentInset;
			insets.bottom += intersection.size.height;
			self.tableView.contentInset = insets;
		} completion:NULL];
	}
}

- (void) CQTableViewController_keyboardWillHide:(NSNotification *) notification {
	NSTimeInterval animationDuration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
	NSUInteger animationCurve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue];

	if (!UIEdgeInsetsEqualToEdgeInsets(_insetsPriorToKeyboardAppearance, UIEdgeInsetsZero)) {
		[UIView animateWithDuration:(animationDuration) delay:.0 options:animationCurve animations:^{
			self.tableView.contentInset = _insetsPriorToKeyboardAppearance;
		} completion:NULL];
	}
}

#pragma mark -

- (void) _reloadTableView {
	if ([self isViewLoaded])
		[_tableView reloadData];
}
@end

NS_ASSUME_NONNULL_END
