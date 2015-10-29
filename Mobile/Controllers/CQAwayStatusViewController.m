#import "CQAwayStatusViewController.h"

#import "CQColloquyApplication.h"
#import "CQTextView.h"

#import "MVChatUser.h"
#import "MVIRCChatConnection.h"

#import "NSNotificationAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@interface CQPreferencesListViewController (Private) <CQPreferencesTextEditViewDelegate, UIActionSheetDelegate>
- (void) editItemAtIndex:(NSUInteger) index;
@end

@implementation CQAwayStatusViewController {
@protected
	UILongPressGestureRecognizer *_longPressGestureRecognizer;
}

- (instancetype) init {
	if (!(self = [super init]))
		return nil;

	self.title = NSLocalizedString(@"Create Away Status…", @"Create Away Status title");

	NSMutableArray <NSString *> *awayStatuses = [[[CQSettingsController settingsController] arrayForKey:@"CQAwayStatuses"] mutableCopy];
	if (!awayStatuses)
		awayStatuses = [[NSMutableArray alloc] init];

	NSString *defaultAwayStatus = [[CQSettingsController settingsController] stringForKey:@"CQAwayStatus"];
	if (defaultAwayStatus.length && ![awayStatuses containsObject:defaultAwayStatus])
		[awayStatuses addObject:defaultAwayStatus];
	else {
		if (awayStatuses.count) {
			if (![self statusIsDefaultAwayStatus:awayStatuses[0]]) {
				for (NSUInteger i = 1; i < awayStatuses.count; i++) {
					NSString *status = awayStatuses[i];
					if ([self statusIsDefaultAwayStatus:status])
						[awayStatuses removeObjectAtIndex:i];
				}

				[awayStatuses insertObject:defaultAwayStatus atIndex:0];
			}
		}
	}

	self.items = awayStatuses;
	self.addItemLabelText = NSLocalizedString(@"New away status", @"New away status label");
	self.noItemsLabelText = NSLocalizedString(@"No away statuses", @"No away statuses label");
	self.editViewTitle = NSLocalizedString(@"Add status", @"Add status label");
	self.editPlaceholder = [NSString stringWithFormat:NSLocalizedString(@"Away from my %@", @"Away from my %@ label"), [UIDevice currentDevice].model];

	self.target = self;
	self.action = @selector(updateAwayStatuses:);

	return self;
}

- (void) viewDidLoad {
	[super viewDidLoad];

	if (!_longPressGestureRecognizer) {
		_longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_tableWasLongPressed:)];
		_longPressGestureRecognizer.cancelsTouchesInView = NO;
		_longPressGestureRecognizer.delaysTouchesBegan = YES;

		[self.tableView addGestureRecognizer:_longPressGestureRecognizer];
	}
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	[[NSNotificationCenter chatCenter] addObserver:self.tableView selector:@selector(reloadData) name:CQSettingsDidChangeNotification object:nil];
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	[[NSNotificationCenter chatCenter] removeObserver:self.tableView name:CQSettingsDidChangeNotification object:nil];
}

#pragma mark -

- (BOOL) statusIsDefaultAwayStatus:(NSString *) status {
	return [status isEqualToString:[[CQSettingsController settingsController] stringForKey:@"CQAwayStatus"]];
}

#pragma mark -

- (void) _tableWasLongPressed:(UILongPressGestureRecognizer *) gestureReconizer {
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

	UIActionSheet *awayStatusActionSheet = [[UIActionSheet alloc] init];
	awayStatusActionSheet.delegate = self;
	[awayStatusActionSheet associateObject:cell forKey:@"userInfo"];

	[awayStatusActionSheet addButtonWithTitle:NSLocalizedString(@"Make Default", @"Make Default button title")];

	awayStatusActionSheet.destructiveButtonIndex = [awayStatusActionSheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	[[CQColloquyApplication sharedApplication] showActionSheet:awayStatusActionSheet forSender:self animated:[UIView areAnimationsEnabled]];
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	return 1;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];

	if (indexPath.row < (NSInteger)self.items.count) {
		cell.textLabel.adjustsFontSizeToFitWidth = YES;
		cell.textLabel.minimumScaleFactor = (15. / cell.textLabel.font.pointSize);
		cell.textLabel.textColor = [UIColor blackColor];
	}

	if ([self statusIsDefaultAwayStatus:cell.textLabel.text])
		cell.textLabel.textColor = [UIColor colorWithRed:(55. / 255.) green:(64. / 255.) blue:(135 / 255.) alpha:1.];

	return cell;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (tableView.editing || indexPath.row > (NSInteger)self.items.count) {
		CQPreferencesTextEditViewController *editingViewController = [[CQPreferencesTextEditViewController alloc] init];
		editingViewController.delegate = self;
		editingViewController.charactersRemainingBeforeDisplay = 25;

		self.customEditingViewController = editingViewController;

		[self editItemAtIndex:indexPath.row];
	} else {
		if (!self.items.count)
			return;

		_connection.awayStatusMessage = [[NSAttributedString alloc] initWithString:self.items[indexPath.row]];

		[self.navigationController dismissViewControllerAnimated:YES completion:NULL];
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
	
	UITableViewCell *cell = [actionSheet associatedObjectForKey:@"userInfo"];
	NSString *awayStatus = cell.textLabel.text;

	[[CQSettingsController settingsController] setObject:awayStatus forKey:@"CQAwayStatus"];

	[self.tableView reloadData];
}

#pragma mark -

- (NSString *) stringForFooterWithTextView:(CQTextView *) textView {
	if (textView.text.length)
		return nil;
	if ([self integerForCountdownInFooterWithTextView:textView] == 1)
		return NSLocalizedString(@"character remaining", @"character remaining tableview footer");
	return NSLocalizedString(@"characters remaining", @"characters remaining tableview footer");
}

- (NSInteger) integerForCountdownInFooterWithTextView:(CQTextView *) textView {
	if (textView.text.length)
		return 0;

	NSString *prefix = [NSString stringWithFormat:@"AWAY %@", textView.text];

	return [_connection bytesRemainingForMessage:_connection.nickname withUsername:_connection.username withAddress:_connection.localUser.address withPrefix:prefix withEncoding:_connection.encoding];;
}

#pragma mark -

- (void) updateAwayStatuses:(CQPreferencesListViewController *) sender {
	NSMutableArray <NSString *> *awayStatuses = [[NSMutableArray alloc] initWithCapacity:sender.items.count];

	for (__strong NSString *awayStatus in sender.items) {
		awayStatus = [awayStatus stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

		if (awayStatus.length && ![awayStatuses containsObject:awayStatus])
			[awayStatuses addObject:awayStatus];
	}

	[[CQSettingsController settingsController] setObject:awayStatuses forKey:@"CQAwayStatuses"];
}
@end

NS_ASSUME_NONNULL_END
