#import "CQAwayStatusViewController.h"

#import "CQPreferencesListViewController.h"
#import "CQTextView.h"

#import "MVChatUser.h"
#import "MVIRCChatConnection.h"

@interface CQPreferencesListViewController (Private)
- (void) editItemAtIndex:(NSUInteger) index;
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
		NSUInteger indexOfDefaultAwayStatus = [awayStatuses indexOfObject:defaultAwayStatus];
		if (indexOfDefaultAwayStatus) {
			[awayStatuses removeObjectAtIndex:indexOfDefaultAwayStatus];
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

	[super dealloc];
}

#pragma mark -

- (BOOL) statusIsIdenticalToStatusFromCell:(NSString *) status {
	NSString *defaultAwayStatus = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQAwayStatus"];
	return defaultAwayStatus.length && [defaultAwayStatus isCaseInsensitiveEqualToString:status];
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
	}

	return cell;
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if ([self statusIsIdenticalToStatusFromCell:[tableView cellForRowAtIndexPath:indexPath].textLabel.text])
		return nil;
	return [super tableView:tableView willSelectRowAtIndexPath:indexPath];
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
	if ([self statusIsIdenticalToStatusFromCell:[tableView cellForRowAtIndexPath:indexPath].textLabel.text])
		return UITableViewCellEditingStyleNone;
	return [super tableView:tableView editingStyleForRowAtIndexPath:indexPath];
}

- (void) tableView:(UITableView *) tableView commitEditingStyle:(UITableViewCellEditingStyle) editingStyle forRowAtIndexPath:(NSIndexPath *) indexPath {
	if (editingStyle == UITableViewCellEditingStyleInsert)
		[self tableView:tableView didSelectRowAtIndexPath:indexPath];
	else if ([self statusIsIdenticalToStatusFromCell:[tableView cellForRowAtIndexPath:indexPath].textLabel.text])
		[tableView deselectRowAtIndexPath:indexPath animated:[UIView areAnimationsEnabled]];
	else [super tableView:tableView commitEditingStyle:editingStyle forRowAtIndexPath:indexPath];
}

- (BOOL) tableView:(UITableView *) tableView canMoveRowAtIndexPath:(NSIndexPath *) indexPath {
	if ([self statusIsIdenticalToStatusFromCell:[tableView cellForRowAtIndexPath:indexPath].textLabel.text])
		return UITableViewCellEditingStyleNone;
	return [super tableView:tableView canMoveRowAtIndexPath:indexPath];
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
