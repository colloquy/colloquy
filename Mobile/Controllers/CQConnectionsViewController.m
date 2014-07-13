#import "CQConnectionsViewController.h"

#import "CQColloquyApplication.h"
#import "CQTableViewSectionHeader.h"
#import "CQAwayStatusController.h"
#import "CQBouncerSettings.h"
#import "CQChatController.h"
#import "CQConnectionTableHeaderView.h"
#import "CQConnectionsController.h"
#import "CQConnectionsNavigationController.h"

#import "CQPreferencesViewController.h"

#import <ChatCore/MVChatConnection.h>

#pragma mark -

@implementation CQConnectionsViewController
- (void) viewDidLoad {
	[super viewDidLoad];

	UIBarButtonItem *settingsItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"settings.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(showPreferences:)];
	self.navigationItem.leftBarButtonItem = settingsItem;
	self.navigationItem.leftBarButtonItem.accessibilityLabel = NSLocalizedString(@"Show Preferences.", @"Voiceover show preferences label");

	self.tableView.allowsSelectionDuringEditing = YES;
}

#pragma mark -

//- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
//	@synchronized([CQConnectionsController defaultController]) {
//		MVChatConnection *connection = [self connectionAtIndexPath:indexPath];
//		if (self.editing) {
//			if (indexPath.section == 0) {
//				[[CQConnectionsController defaultController] showNewConnectionPrompt:nil];
//				[tableView deselectRowAtIndexPath:indexPath animated:[UIView areAnimationsEnabled]];
//			} else [self.navigationController editConnection:connection];
//		}
//	}
//}

- (UITableViewCellEditingStyle) tableView:(UITableView *) tableView editingStyleForRowAtIndexPath:(NSIndexPath *) indexPath {
	switch (indexPath.section) {
	case 0:
		return UITableViewCellEditingStyleInsert;
	case 1:
		return UITableViewCellEditingStyleDelete;
	default:
		return UITableViewCellEditingStyleNone;
	}
}

- (void) tableView:(UITableView *) tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *) indexPath {
//	[self.navigationController editConnection:[self connectionAtIndexPath:indexPath]];
}

- (void) tableView:(UITableView *) tableView commitEditingStyle:(UITableViewCellEditingStyle) editingStyle forRowAtIndexPath:(NSIndexPath *) indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete)
		return;

	@synchronized([CQConnectionsController defaultController]) {
		_ignoreNotifications = YES;
		[[CQConnectionsController defaultController] removeConnectionAtIndex:indexPath.row];
		_ignoreNotifications = NO;

		[self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationRight];
	}
}

- (BOOL) tableView:(UITableView *) tableView canMoveRowAtIndexPath:(NSIndexPath *) indexPath {
	if (!tableView.editing)
		return NO;
	if (indexPath.section == 0)
		return NO;
	return YES;
}

- (NSIndexPath *) tableView:(UITableView *) tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *) sourceIndexPath toProposedIndexPath:(NSIndexPath *) proposedDestinationIndexPath {
	if (tableView.editing && sourceIndexPath.section == 0)
		return sourceIndexPath;

	if (sourceIndexPath.section == proposedDestinationIndexPath.section)
		return proposedDestinationIndexPath;

	if (proposedDestinationIndexPath.section < sourceIndexPath.section)
		return [NSIndexPath indexPathForRow:0 inSection:sourceIndexPath.section];

	NSUInteger rows = [self tableView:tableView numberOfRowsInSection:sourceIndexPath.section];
	return [NSIndexPath indexPathForRow:(rows - 1) inSection:sourceIndexPath.section];
}

- (void) tableView:(UITableView *) tableView moveRowAtIndexPath:(NSIndexPath *) fromIndexPath toIndexPath:(NSIndexPath *) toIndexPath {
	if (tableView.editing && fromIndexPath.section == 0)
		return;

	if (fromIndexPath.section != toIndexPath.section) {
		NSAssert(NO, @"Should not reach this point.");
		return;
	}

	@synchronized([CQConnectionsController defaultController]) {
		if (fromIndexPath.section == 1) {
			_ignoreNotifications = YES;
			[[CQConnectionsController defaultController] moveConnectionAtIndex:fromIndexPath.row toIndex:toIndexPath.row];
			_ignoreNotifications = NO;
			return;
		}

		NSArray *bouncers = [CQConnectionsController defaultController].bouncers;
		CQBouncerSettings *settings = bouncers[(fromIndexPath.section - 2)];

		_ignoreNotifications = YES;
		[[CQConnectionsController defaultController] moveConnectionAtIndex:fromIndexPath.row toIndex:toIndexPath.row forBouncerIdentifier:settings.identifier];
		_ignoreNotifications = NO;
	}
}

#pragma mark -

- (void) showPreferences:(id) sender {
	CQPreferencesViewController *preferencesViewController = [[CQPreferencesViewController alloc] init];

	[[CQColloquyApplication sharedApplication] presentModalViewController:preferencesViewController animated:[UIView areAnimationsEnabled]];

}
@end
