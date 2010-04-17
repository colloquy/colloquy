#import "CQAwayStatusViewController.h"

#import "CQPreferencesListViewController.h"

#import "CQTextView.h"

#import "MVIRCChatConnection.h"
#import "MVChatUser.h"

#import "UIDeviceAdditions.h"

@interface CQPreferencesListViewController (Private)
- (void) editItemAtIndex:(NSUInteger) index;
@end

@implementation CQAwayStatusViewController
@synthesize connection = _connection;

- (id) init {
	if (!(self = [super init]))
		return nil;

	_items = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"CQAwayStatuses"] mutableCopy];
	_addItemLabelText = NSLocalizedString(@"New away status", @"New away status label");
	_noItemsLabelText = NSLocalizedString(@"No away statuses", @"No away statuses label");
	_editViewTitle = NSLocalizedString(@"Add status", @"Add status label");
	_editPlaceholder = [[NSString alloc] initWithFormat:NSLocalizedString(@"Away from my %@", @"Away from my %@ label"), [UIDevice currentDevice].model];;

	self.title = NSLocalizedString(@"Create Away Status…", @"Create Away Status title");
	self.target = self;
	self.action = @selector(updateAwayStatuses:);

	return self;
}

- (void) dealloc {
	[_connection release];

	[super dealloc];
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	return 1;
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	return indexPath;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (tableView.editing || indexPath.row > _items.count) {
		CQPreferencesTextEditViewController *editingViewController = [[CQPreferencesTextEditViewController alloc] init];
		editingViewController.delegate = self;
		editingViewController.assignedPlaceholder = _editPlaceholder;
		editingViewController.charactersRemainingBeforeDisplay = 25;

		id old = _customEditingViewController;
		_customEditingViewController = [editingViewController retain];
		[old release];

		[self editItemAtIndex:indexPath.row];

		[editingViewController release];
	} else {
		if (!_items.count) {
			[self setEditing:YES animated:YES];
			[self tableView:tableView didSelectRowAtIndexPath:indexPath];

			return;
		}

		_connection.awayStatusMessage = [_items objectAtIndex:indexPath.row];

		// Better way to close the view?
		UIBarButtonItem *doneItem = self.navigationItem.leftBarButtonItem;
		[doneItem.target performSelector:doneItem.action];
	}
}

- (void) tableView:(UITableView *) tableView commitEditingStyle:(UITableViewCellEditingStyle) editingStyle forRowAtIndexPath:(NSIndexPath *) indexPath {
	if (editingStyle == UITableViewCellEditingStyleInsert)
		[self tableView:tableView didSelectRowAtIndexPath:indexPath];
	else [super tableView:tableView commitEditingStyle:editingStyle forRowAtIndexPath:indexPath];
}

#pragma mark -

- (NSString *) stringForFooterWithTextView:(CQTextView *) textView {
	if ([textView.text isEqualToString:textView.placeholder])
		return nil;
	return [NSLocalizedString(@"characters remaining", @"characters remaining tableview footer") autorelease];
}

- (NSInteger) integerForCountdownInFooterWithTextView:(CQTextView *) textView {
	if ([textView.text isEqualToString:textView.placeholder])
		return 0;

	NSString *prefix = [NSString stringWithFormat:@"AWAY %@", textView.text];

	return [_connection bytesRemainingForMessage:_connection.nickname withUsername:_connection.username withAddress:_connection.localUser.address withPrefix:prefix withEncoding:_connection.encoding];;
}

#pragma mark -

- (void) updateAwayStatuses:(CQPreferencesListViewController *) sender {
	NSInteger count = sender.items.count;
	NSMutableArray *awayStatuses = [[NSMutableArray alloc] initWithCapacity:count];

	for (NSString *awayStatus in sender.items) {
		awayStatus = [awayStatus stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

		if (awayStatus.length && ![awayStatuses containsObject:awayStatus])
			[awayStatuses addObject:awayStatus];
	}

	_items = awayStatuses;

	[[NSUserDefaults standardUserDefaults] setObject:_items forKey:@"CQAwayStatuses"];

	[awayStatuses release];
}
@end
