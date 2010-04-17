#import "CQPreferencesTextEditViewController.h"

#import "CQTextView.h"
#import "CQPreferencesTextViewCell.h"

#import "MVIRCChatConnection.h"
#import "MVChatUser.h"

@interface CQPreferencesTextEditViewController (Private)
- (void) updateFooterView;
@end

@implementation CQPreferencesTextEditViewController
@synthesize delegate = _delegate;
@synthesize listItemText = _listItemText;
@synthesize listItemPlaceholder = _listItemPlaceholder;
@synthesize assignedPlaceholder = _assignedPlaceholder;
@synthesize charactersRemainingBeforeDisplay = _charactersRemainingBeforeDisplay;

- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	self.tableView.dataSource = self;
	self.tableView.delegate = self;
	self.tableView.scrollEnabled = NO;

	_footerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_footerLabel.font = [UIFont systemFontOfSize:14.];
	_footerLabel.textAlignment = UITextAlignmentCenter;
	_footerLabel.backgroundColor = [UIColor clearColor];
	_footerLabel.adjustsFontSizeToFitWidth = NO;

	// red: 76 / 255, green: 86 / 255, blue: 108 / 255
	_footerLabel.textColor = [UIColor colorWithRed:0.298039215686275 green:0.337254901960784 blue:0.423529411764706 alpha:1.];

	_charactersRemainingBeforeDisplay = NSIntegerMin;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateFooterView) name:UITextViewTextDidChangeNotification object:nil];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_delegate release];

	[_listItemText release];
	[_listItemPlaceholder release];
	[_assignedPlaceholder release];

	[_footerLabel release];

	[super dealloc];
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

	id old = _listItemText;
	_listItemText = [textView.text copy];
	[old release];

	BOOL stringForFooterWithTextView = [_delegate respondsToSelector:@selector(stringForFooterWithTextView:)];
	BOOL integerCountdown = [_delegate respondsToSelector:@selector(integerForCountdownInFooterWithTextView:)];

	if (!stringForFooterWithTextView && !integerCountdown) {
		_footerLabel.frame = CGRectZero;
		return;
	}

	NSString *message = nil;
	if (stringForFooterWithTextView)
		message = [_delegate stringForFooterWithTextView:textView];

	NSInteger charactersRemaining = 0;
	if (integerCountdown)
		charactersRemaining = [_delegate integerForCountdownInFooterWithTextView:textView];

	BOOL emptyFrame = CGRectEqualToRect(_footerLabel.frame, CGRectZero);

	if (!message.length || (integerCountdown && charactersRemaining > _charactersRemainingBeforeDisplay)) {
		if (emptyFrame)
			return;

		[UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.15];
		[UIView setAnimationBeginsFromCurrentState:YES];

		_footerLabel.frame = CGRectZero;

		[UIView commitAnimations];

		return;
	}

	// re-set the tableFooterView every time it will be displayed for the x and y coordinates, since they might not be around from last time;
	// the frame may have been set to CGRectZero previously
	self.tableView.tableFooterView = _footerLabel;

	if (integerCountdown && stringForFooterWithTextView)
		_footerLabel.text = [NSString stringWithFormat:@"%d %@", charactersRemaining, message];
	else if (stringForFooterWithTextView)
		_footerLabel.text = message;
	else _footerLabel.text = [NSString stringWithFormat:@"%d", charactersRemaining];

	// only animate if we're showing up on screen for the first time
	if (emptyFrame) {
		[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.15];
		[UIView setAnimationBeginsFromCurrentState:YES];
	}

	[_footerLabel sizeToFit];

	CGRect frame = _footerLabel.frame;
	_footerLabel.frame = CGRectMake((self.tableView.frame.size.width / 2) - floor((frame.size.width / 2)), frame.origin.y, frame.size.width, frame.size.height);

	if (emptyFrame)
		[UIView commitAnimations];
}

#pragma mark -

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	return 1;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	return 1;
}

#pragma mark -

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	CQPreferencesTextViewCell *cell = [CQPreferencesTextViewCell reusableTableViewCellInTableView:self.tableView];
	cell.textView.text = _listItemText;
	cell.textView.placeholder = _listItemPlaceholder;

	tableView.rowHeight = cell.height;

	return cell;
}

- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation) fromInterfaceOrientation {
	CQPreferencesTextViewCell *cell = (CQPreferencesTextViewCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
	[cell layoutSubviews];

	self.tableView.rowHeight = cell.height;

	[self.tableView setNeedsDisplay];
}
@end
