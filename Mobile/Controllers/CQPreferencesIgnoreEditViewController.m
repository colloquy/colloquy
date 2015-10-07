#import "CQPreferencesIgnoreEditViewController.h"

#import "CQPreferencesListViewController.h"

#import "CQPreferencesTextCell.h"
#import "CQPreferencesSwitchCell.h"

#import "KAIgnoreRule.h"

#import "NSStringAdditions.h"

enum {
	CQPreferencesIgnoreRowNameOrMask,
	CQPreferencesIgnoreRowDisplayName,
};

enum {
	CQPreferencesIgnoreRowRooms,
};

enum {
	CQPreferencesIgnoreRowPermanent,
};

enum {
	CQPreferencesIgnoreSectionText,
	CQPreferencesIgnoreSectionRooms,
	CQPreferencesIgnoreSectionPermanent
};

@implementation CQPreferencesIgnoreEditViewController
- (instancetype) initWithConnection:(MVChatConnection *) connection {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	_connection = connection;

	return self;
}

#pragma mark -

- (KAIgnoreRule *) _ignoreRule {
	if (![_listItem isKindOfClass:[KAIgnoreRule class]]) {
		_listItem = [[KAIgnoreRule alloc] init];
	}

	return _listItem;
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	return 3;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	if (section == CQPreferencesIgnoreSectionText)
		return 2;
	if (section == CQPreferencesIgnoreSectionRooms)
		return 1;
	if (section == CQPreferencesIgnoreSectionPermanent)
		return 1;
	return 0;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == CQPreferencesIgnoreSectionText) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];
		cell.textField.tag = indexPath.row;
		cell.textEditAction = @selector(listItemChanged:);

		if (indexPath.row == CQPreferencesIgnoreRowNameOrMask) {
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textLabel.text = NSLocalizedString(@"Username", @"Username label");
			cell.textField.placeholder = _listItemPlaceholder;
			cell.textField.text = self._ignoreRule.user;
			if (!cell.textField.text)
				cell.textField.text = self._ignoreRule.mask;
		} else if (indexPath.row == CQPreferencesIgnoreRowDisplayName) {
			cell.textLabel.text = NSLocalizedString(@"Display Name", @"Display Name label");
			cell.textField.text = self._ignoreRule.friendlyName;
			cell.textField.placeholder = NSLocalizedString(@"Optional", @"Optional cell label");;
		}

		return cell;
	}

	if (indexPath.section == CQPreferencesIgnoreSectionRooms) {
		UITableViewCell *cell = [UITableViewCell reusableTableViewCellWithStyle:UITableViewCellStyleValue1 inTableView:tableView];
		cell.textLabel.text = NSLocalizedString(@"Rooms", @"Rooms");
		cell.detailTextLabel.text = [self._ignoreRule.rooms componentsJoinedByString:@", "];
		if (!cell.detailTextLabel.text)
			cell.detailTextLabel.text = NSLocalizedString(@"Optional", @"Optional detail text");
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		return cell;
	}

	if (indexPath.section == CQPreferencesIgnoreSectionPermanent) {
		CQPreferencesSwitchCell *switchCell = [CQPreferencesSwitchCell reusableTableViewCellInTableView:tableView];
		switchCell.on = self._ignoreRule.permanent;
		switchCell.switchAction = @selector(permanenceToggled:);
		switchCell.textLabel.text = NSLocalizedString(@"Permanent", @"Permanent rule");

		return switchCell;
	}

	return nil;
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == CQPreferencesIgnoreSectionRooms)
		return indexPath;
	return [super tableView:tableView willSelectRowAtIndexPath:indexPath];
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == CQPreferencesIgnoreSectionRooms) {
		CQPreferencesListViewController *listViewController = [[CQPreferencesListViewController alloc] init];
		listViewController.title = NSLocalizedString(@"Rooms", @"Rooms List Title");
		listViewController.items = self._ignoreRule.rooms;
		if ([[CQSettingsController settingsController] boolForKey:@"CQShowsChatIcons"])
			listViewController.itemImage = [UIImage imageNamed:@"roomIconSmall.png"];
		listViewController.addItemLabelText = NSLocalizedString(@"Add chat room", @"Add chat room label");
		listViewController.noItemsLabelText = NSLocalizedString(@"No chat rooms", @"No chat rooms label");
		listViewController.editViewTitle = NSLocalizedString(@"Edit Chat Room", @"Edit Chat Room view title");
		listViewController.editPlaceholder = NSLocalizedString(@"Chat Room", @"Chat Room placeholder");
		listViewController.target = self;
		listViewController.action = @selector(ignoreRoomsChanged:);

		[self endEditing];

		[self.navigationController pushViewController:listViewController animated:YES];

	}

	[tableView deselectRowAtIndexPath:indexPath animated:[UIView areAnimationsEnabled]];
}

#pragma mark -

- (void) listItemChanged:(CQPreferencesTextCell *) sender {
	switch (sender.textField.tag) {
	case CQPreferencesIgnoreRowNameOrMask:
		if (sender.textField.text.isValidIRCMask)
			self._ignoreRule.mask = sender.textField.text;
		else self._ignoreRule.user = sender.textField.text;
		break;
	case CQPreferencesIgnoreRowDisplayName:
		self._ignoreRule.friendlyName = sender.textField.text;
		break;
	}
}

- (void) ignoreRoomsChanged:(CQPreferencesListViewController *) sender {
	self._ignoreRule.rooms = sender.items;
}

- (void) permanenceToggled:(CQPreferencesSwitchCell *) sender {
	self._ignoreRule.permanent = sender.on;
}
@end
