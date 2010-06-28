#import "CQAwayStatusViewController.h"

#import "CQColloquyApplication.h"
#import "CQPreferencesListViewController.h"
#import "CQActionSheet.h"
#import "CQTextView.h"

#import "MVChatUser.h"
#import "MVIRCChatConnection.h"

@interface CQPreferencesListViewController (Private)
- (void) editItemAtIndex:(NSUInteger) index;
@end

@interface CQAwayStatusViewController (Private)
- (BOOL) statusIsDefaultAwayStatus:(NSString *) status;
@end

@implementation CQAwayStatusViewController
@synthesize connection = _connection;

- (id) init {
	if (!(self = [super init]))
		return nil;

	self.title = NSLocalizedString(@"Create Away Status…", @"Create Away Status title");
	NSMutableArray *awayStatuses = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"CQAwayStatuses"] mutableCopy];
	if (!awayStatuses.count)
		awayStatuses = [[NSMutableArray alloc] init];
	NSString *defaultAwayStatus = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQAwayStatus"];
	if (defaultAwayStatus.length && ![awayStatuses containsObject:defaultAwayStatus])
		[awayStatuses addObject:defaultAwayStatus];
	else {
		if (![self statusIsDefaultAwayStatus:[awayStatuses objectAtIndex:0]]) {
			for (NSUInteger i = 1; i <  awayStatuses.count; i++) {
				NSString *status = [awayStatuses objectAtIndex:i];
				if ([self statusIsDefaultAwayStatus:status])
					[awayStatuses removeObjectAtIndex:i];
			}

			[awayStatuses insertObject:defaultAwayStatus atIndex:0];
		}
	}

	self.items = awayStatuses;
	self.addItemLabelText = NSLocalizedString(@"New away status", @"New away status label");
	self.noItemsLabelText = NSLocalizedString(@"No away statuses", @"No away statuses label");
	self.editViewTitle = NSLocalizedString(@"Add status", @"Add status label");
	self.editPlaceholder = [[NSString alloc] initWithFormat:NSLocalizedString(@"Away from my %@", @"Away from my %@ label"), [UIDevice currentDevice].model];;

	self.target = self;
	self.action = @selector(updateAwayStatuses:);

	[awayStatuses release];

	return self;
}

- (void) dealloc {
	[_connection release];
	[_longPressGestureRecognizer release];

	[super dealloc];
}

- (void) viewDidLoad {
	[super viewDidLoad];

	if (!_longPressGestureRecognizer && [[UIDevice currentDevice].systemVersion doubleValue] >= 3.2) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_3_2
		_longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_tableWasLongPressed:)];
		_longPressGestureRecognizer.cancelsTouchesInView = NO;
		_longPressGestureRecognizer.delaysTouchesBegan = YES;
		[self.tableView addGestureRecognizer:_longPressGestureRecognizer];
#endif
	}
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	[[NSNotificationCenter defaultCenter] addObserver:self.tableView selector:@selector(reloadData) name:NSUserDefaultsDidChangeNotification object:nil];
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	[[NSNotificationCenter defaultCenter] removeObserver:self.tableView name:NSUserDefaultsDidChangeNotification object:nil];
}

#pragma mark -

- (BOOL) statusIsDefaultAwayStatus:(NSString *) status {
	return [status isEqualToString:[[NSUserDefaults standardUserDefaults] stringForKey:@"CQAwayStatus"]];
}

#pragma mark -

- (void) _tableWasLongPressed:(UILongPressGestureRecognizer *) gestureReconizer {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_3_2
	if (gestureReconizer.state != UIGestureRecognizerStateBegan)
		return;

	if (self.tableView.editing)
		return;

	NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:[gestureReconizer locationInView:self.tableView]];
	if (!indexPath)
		return;

	UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
	if (!cell)
		return;

	if ([self statusIsDefaultAwayStatus:cell.textLabel.text])
		return;

	CQActionSheet *awayStatusActionSheet = [[CQActionSheet alloc] init];
	awayStatusActionSheet.delegate = self;
	awayStatusActionSheet.userInfo = cell;

	[awayStatusActionSheet addButtonWithTitle:NSLocalizedString(@"Make Default", @"Make Default button title")];

	awayStatusActionSheet.destructiveButtonIndex = [awayStatusActionSheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	[[CQColloquyApplication sharedApplication] showActionSheet:awayStatusActionSheet forSender:self animated:[UIView areAnimationsEnabled]];

	[awayStatusActionSheet release];
#endif
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	return 1;
}


- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];

	if (indexPath.row < _items.count) {
		cell.textLabel.adjustsFontSizeToFitWidth = YES;
		cell.textLabel.minimumFontSize = 15.;
		cell.textLabel.textColor = [UIColor blackColor];
	}

	if ([self statusIsDefaultAwayStatus:cell.textLabel.text])
		cell.textLabel.textColor = [UIColor colorWithRed:(55. / 255.) green:(64. / 255.) blue:(135 / 255.) alpha:1.];

	return cell;
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if ([self statusIsDefaultAwayStatus:[tableView cellForRowAtIndexPath:indexPath].textLabel.text])
		return nil;
	return indexPath;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (tableView.editing || indexPath.row > _items.count) {
		CQPreferencesTextEditViewController *editingViewController = [[CQPreferencesTextEditViewController alloc] init];
		editingViewController.delegate = self;
		editingViewController.charactersRemainingBeforeDisplay = 25;

		id old = _customEditingViewController;
		_customEditingViewController = [editingViewController retain];
		[old release];

		[self editItemAtIndex:indexPath.row];

		[editingViewController release];
	} else {
		if (!_items.count)
			return;

		_connection.awayStatusMessage = [_items objectAtIndex:indexPath.row];

		// Better way to close the view?
		UIBarButtonItem *doneItem = self.navigationItem.leftBarButtonItem;
		[doneItem.target performSelector:doneItem.action];
	}
}

- (UITableViewCellEditingStyle) tableView:(UITableView *) tableView editingStyleForRowAtIndexPath:(NSIndexPath *) indexPath {
	if ([self statusIsDefaultAwayStatus:[tableView cellForRowAtIndexPath:indexPath].textLabel.text])
		return UITableViewCellEditingStyleNone;
	return [super tableView:tableView editingStyleForRowAtIndexPath:indexPath];
}

- (void) tableView:(UITableView *) tableView commitEditingStyle:(UITableViewCellEditingStyle) editingStyle forRowAtIndexPath:(NSIndexPath *) indexPath {
	if (editingStyle == UITableViewCellEditingStyleInsert)
		[self tableView:tableView didSelectRowAtIndexPath:indexPath];
	else if ([self statusIsDefaultAwayStatus:[tableView cellForRowAtIndexPath:indexPath].textLabel.text])
		[tableView deselectRowAtIndexPath:indexPath animated:[UIView areAnimationsEnabled]];
	else [super tableView:tableView commitEditingStyle:editingStyle forRowAtIndexPath:indexPath];
}

- (BOOL) tableView:(UITableView *) tableView canMoveRowAtIndexPath:(NSIndexPath *) indexPath {
	if ([self statusIsDefaultAwayStatus:[tableView cellForRowAtIndexPath:indexPath].textLabel.text])
		return UITableViewCellEditingStyleNone;
	return [super tableView:tableView canMoveRowAtIndexPath:indexPath];
}

#pragma mark -

- (void) actionSheet:(UIActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (buttonIndex == actionSheet.destructiveButtonIndex)
		return;
	
	UITableViewCell *cell = ((CQActionSheet *)actionSheet).userInfo;
	NSString *awayStatus = cell.textLabel.text;

	[[NSUserDefaults standardUserDefaults] setObject:awayStatus forKey:@"CQAwayStatus"];

	[self.tableView reloadData];
}

#pragma mark -

- (NSString *) stringForFooterWithTextView:(CQTextView *) textView {
	if (textView.isPlaceholderText)
		return nil;
	if ([self integerForCountdownInFooterWithTextView:textView] == 1)
		return NSLocalizedString(@"character remaining", @"character remaining tableview footer");
	return NSLocalizedString(@"characters remaining", @"characters remaining tableview footer");
}

- (NSInteger) integerForCountdownInFooterWithTextView:(CQTextView *) textView {
	if (textView.isPlaceholderText)
		return 0;

	NSString *prefix = [NSString stringWithFormat:@"AWAY %@", textView.text];

	return [_connection bytesRemainingForMessage:_connection.nickname withUsername:_connection.username withAddress:_connection.localUser.address withPrefix:prefix withEncoding:_connection.encoding];;
}

#pragma mark -

- (void) updateAwayStatuses:(CQPreferencesListViewController *) sender {
	NSMutableArray *awayStatuses = [[NSMutableArray alloc] initWithCapacity:sender.items.count];

	for (NSString *awayStatus in sender.items) {
		awayStatus = [awayStatus stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

		if (awayStatus.length && ![awayStatuses containsObject:awayStatus])
			[awayStatuses addObject:awayStatus];
	}

	[[NSUserDefaults standardUserDefaults] setObject:awayStatuses forKey:@"CQAwayStatuses"];

	[awayStatuses release];
}
@end
