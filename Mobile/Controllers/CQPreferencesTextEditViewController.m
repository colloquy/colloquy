#import "CQPreferencesTextEditViewController.h"

#import "CQTextView.h"
#import "CQPreferencesTextViewCell.h"

NS_ASSUME_NONNULL_BEGIN

@implementation CQPreferencesTextEditViewController {
	id <CQPreferencesTextEditViewDelegate> __weak _delegate;

	NSString *_listItemText;
	NSString *_listItemPlaceholder;

	NSInteger _charactersRemainingBeforeDisplay;

	UILabel *_footerLabel;
}

@synthesize listItem = _listItemText;

- (instancetype) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	self.tableView.dataSource = self;
	self.tableView.delegate = self;
	self.tableView.scrollEnabled = NO;

	_footerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_footerLabel.font = [UIFont systemFontOfSize:14.];
	_footerLabel.textAlignment = NSTextAlignmentCenter;
	_footerLabel.backgroundColor = [UIColor clearColor];
	_footerLabel.adjustsFontSizeToFitWidth = NO;

	// red: 76 / 255, green: 86 / 255, blue: 108 / 255
	_footerLabel.textColor = [UIColor colorWithRed:0.298039215686275 green:0.337254901960784 blue:0.423529411764706 alpha:1.];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateFooterView) name:UITextViewTextDidChangeNotification object:nil];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -

- (NSString *) listItemText {
	CQPreferencesTextViewCell *cell = (CQPreferencesTextViewCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
	return cell.textView.text;
}

#pragma mark -

- (void) viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];

	[self updateFooterView];
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	[[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]] resignFirstResponder];
}

#pragma mark -

// Not using - tableView:viewForFooterInSection: because it will create an infinite loop with - tableView:cellForRowAtIndexPath:
- (void) updateFooterView {
	CQPreferencesTextViewCell *cell = (CQPreferencesTextViewCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
	CQTextView *textView = cell.textView;

	_listItemText = [textView.text copy];

	__strong __typeof__((_delegate)) delegate = _delegate;

	BOOL stringForFooterWithTextView = [delegate respondsToSelector:@selector(stringForFooterWithTextView:)];
	BOOL integerCountdown = [delegate respondsToSelector:@selector(integerForCountdownInFooterWithTextView:)];

	if (!stringForFooterWithTextView && !integerCountdown) {
		_footerLabel.frame = CGRectZero;
		return;
	}

	NSString *message = nil;
	if (stringForFooterWithTextView)
		message = [delegate stringForFooterWithTextView:textView];

	NSInteger charactersRemaining = 0;
	if (integerCountdown)
		charactersRemaining = [delegate integerForCountdownInFooterWithTextView:textView];

	BOOL emptyFrame = CGRectEqualToRect(_footerLabel.frame, CGRectZero);

	if (!message.length || (integerCountdown && charactersRemaining > _charactersRemainingBeforeDisplay)) {
		if (emptyFrame)
			return;

		[UIView animateWithDuration:.15 delay:.0 options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState) animations:^{
			_footerLabel.frame = CGRectZero;
		} completion:NULL];

		return;
	}

	// re-set the tableFooterView every time it will be displayed for the x and y coordinates, since they might not be around from last time;
	// the frame may have been set to CGRectZero previously
	self.tableView.tableFooterView = _footerLabel;

	if (integerCountdown && stringForFooterWithTextView)
		_footerLabel.text = [NSString stringWithFormat:@"%tu %@", charactersRemaining, message];
	else if (stringForFooterWithTextView)
		_footerLabel.text = message;
	else _footerLabel.text = [NSString stringWithFormat:@"%tu", charactersRemaining];

	// only animate if we're showing up on screen for the first time
	[UIView animateWithDuration:(emptyFrame ? .15 : .0) delay:.0 options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState) animations:^{
		[_footerLabel sizeToFit];

		CGRect frame = _footerLabel.frame;
		_footerLabel.frame = CGRectMake((self.tableView.frame.size.width / 2) - floor((frame.size.width / 2)), frame.origin.y, frame.size.width, frame.size.height);
	} completion:NULL];
}

#pragma mark -

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	return 1;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	return 1;
}

#pragma mark -

- (CGFloat) tableView:(UITableView *) tableView heightForRowAtIndexPath:(NSIndexPath *) indexPath {
	return [CQPreferencesTextViewCell height];
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	CQPreferencesTextViewCell *cell = [CQPreferencesTextViewCell reusableTableViewCellInTableView:self.tableView];
	cell.textView.text = _listItemText;
	cell.textView.placeholder = _listItemPlaceholder;

	return cell;
}

- (void) viewWillTransitionToSize:(CGSize) size withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>) coordinator {
	[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
	[self.tableView reloadData];
}

@end

NS_ASSUME_NONNULL_END
