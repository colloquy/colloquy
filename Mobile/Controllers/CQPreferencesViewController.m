#import "CQPreferencesViewController.h"

#import "CQPreferencesListViewController.h"

#import "CQPreferencesSwitchCell.h"
#import "CQPreferencesTextCell.h"

// These are defined as constants because they are used in Settings.app
static NSString *const CQPSGroupSpecifier = @"PSGroupSpecifier";
static NSString *const CQPSTextFieldSpecifier = @"PSTextFieldSpecifier";
static NSString *const CQPSToggleSwitchSpecifier = @"PSToggleSwitchSpecifier";
static NSString *const CQPSChildPaneSpecifier = @"PSChildPaneSpecifier";
static NSString *const CQPSMultiValueSpecifier = @"PSMultiValueSpecifier";
static NSString *const CQPSTitleValueSpecifier = @"PSTitleValueSpecifier";

static NSString *const CQPSType = @"Type";
static NSString *const CQPSTitle = @"Title";
static NSString *const CQPSKey = @"Key";
static NSString *const CQPSDefaultValue = @"DefaultValue";
static NSString *const CQPSFile = @"File";
static NSString *const CQPSValues = @"Values";
static NSString *const CQPSTitles = @"Titles";
static NSString *const CQPSAutocorrectType = @"AutocorrectionType";
static NSString *const CQPSPreferenceSpecifiers = @"PreferenceSpecifiers";

@implementation CQPreferencesViewController
- (id) initWithRootPlist {
	return [self initWithPlistNamed:@"Root"];
}

- (id) initWithPlistNamed:(NSString *) plist {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	_preferences = [[NSMutableArray alloc] init];

	[self performSelectorInBackground:@selector(_readSettingsFromPlist:) withObject:plist];

	return self;
}

- (void) dealloc {
	[_preferences release];
	[_selectedIndexPath release];

	[super dealloc];
}

#pragma mark -

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	if (_selectedIndexPath) {
		[self.tableView beginUpdates];
		[self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:_selectedIndexPath] withRowAnimation:UITableViewRowAnimationNone];
		[self.tableView endUpdates];
	}
}

#pragma mark -

- (void) _readSettingsFromPlist:(NSString *) plist {
	NSString *settingsBundlePath = [[NSBundle mainBundle] pathForResource:@"Settings" ofType:@"bundle"];
	NSString *settingsPath = [settingsBundlePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", plist]];

	NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:settingsPath];
	if (!preferences)
		return;

	if (!self.title.length)
		self.title = [preferences objectForKey:CQPSTitle];
	if (!self.title.length)
		self.title = [plist capitalizedStringWithLocale:[NSLocale currentLocale]];

	__block NSMutableDictionary *workingSection = nil;
	[[preferences objectForKey:CQPSPreferenceSpecifiers] enumerateObjectsUsingBlock:^(id object, NSUInteger index, BOOL *stop) {
		if ([[object objectForKey:CQPSType] isEqualToString:CQPSGroupSpecifier]) {
			id old = workingSection;
			workingSection = [object mutableCopy];
			[old release];

			[workingSection setObject:[NSMutableArray array] forKey:@"rows"];

			[_preferences addObject:workingSection];
		} else {
			NSMutableArray *rows = nil;
			if (_preferences.count)
				rows = [[[_preferences objectAtIndex:(_preferences.count - 1)] objectForKey:@"rows"] retain];

			if (!rows) {
				rows = [[NSMutableArray alloc] init];
				workingSection = [[NSMutableDictionary alloc] init];
				[workingSection setObject:rows forKey:@"rows"];

				[_preferences addObject:workingSection];
			}

			[rows addObject:[[object copy] autorelease]];

			[rows release];
		}
	}];
	[workingSection release];

	[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	return _preferences.count;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	return [[[_preferences objectAtIndex:section] objectForKey:@"rows"] count];
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	return [[_preferences objectAtIndex:section] objectForKey:CQPSTitle];
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	NSDictionary *rowDictionary = [[[_preferences objectAtIndex:indexPath.section] objectForKey:@"rows"] objectAtIndex:indexPath.row];
	if ([[rowDictionary objectForKey:CQPSType] isEqualToString:CQPSTitleValueSpecifier])
		return nil;
	return indexPath;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	NSDictionary *rowDictionary = [[[_preferences objectAtIndex:indexPath.section] objectForKey:@"rows"] objectAtIndex:indexPath.row];
	id key = [rowDictionary objectForKey:CQPSKey];
	id value = nil;
	if (key) {
		value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
		if (!value)
			value = [rowDictionary objectForKey:CQPSDefaultValue];
	}

	if ([[rowDictionary objectForKey:CQPSType] isEqualToString:CQPSTextFieldSpecifier]) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];
		cell.textField.text = value;
		cell.textLabel.text = [rowDictionary objectForKey:CQPSTitle];
		cell.textFieldBlock = ^(UITextField *textField) {
			[[NSUserDefaults standardUserDefaults] setObject:textField.text forKey:key];
		};

		return cell;
	} else if ([[rowDictionary objectForKey:CQPSType] isEqualToString:CQPSToggleSwitchSpecifier]) {
		CQPreferencesSwitchCell *cell = [CQPreferencesSwitchCell reusableTableViewCellInTableView:tableView];
		cell.switchControl.on = [value boolValue];
		cell.textLabel.text = [rowDictionary objectForKey:CQPSTitle];
		cell.switchControlBlock = ^(UISwitch *switchControl) {
			[[NSUserDefaults standardUserDefaults] setBool:switchControl.on forKey:key];
		};

		return cell;
	} else if ([[rowDictionary objectForKey:CQPSType] isEqualToString:CQPSChildPaneSpecifier]) {
		UITableViewCell *cell = [UITableViewCell reusableTableViewCellWithStyle:UITableViewCellStyleValue1 inTableView:tableView];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.detailTextLabel.text = value;
		cell.textLabel.text = [rowDictionary objectForKey:CQPSTitle];

		return cell;
	} else if ([[rowDictionary objectForKey:CQPSType] isEqualToString:CQPSMultiValueSpecifier]) {
		UITableViewCell *cell = [UITableViewCell reusableTableViewCellWithStyle:UITableViewCellStyleValue1 inTableView:tableView];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.textLabel.text = [rowDictionary objectForKey:CQPSTitle];

		NSUInteger index = [[rowDictionary objectForKey:CQPSValues] indexOfObject:value];
		cell.detailTextLabel.text = [[rowDictionary objectForKey:CQPSTitles] objectAtIndex:index];

		return cell;
	} else if ([[rowDictionary objectForKey:CQPSType] isEqualToString:CQPSTitleValueSpecifier]) {
		UITableViewCell *cell = [UITableViewCell reusableTableViewCellWithStyle:UITableViewCellStyleValue1 inTableView:tableView];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.textLabel.text = [rowDictionary objectForKey:CQPSTitle];
		cell.detailTextLabel.text = [rowDictionary objectForKey:CQPSDefaultValue];

		return cell;
	}

	return nil;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	id old = _selectedIndexPath;
	_selectedIndexPath = [indexPath retain];
	[old release];

	UIViewController *viewController = nil;
	NSDictionary *rowDictionary = [[[_preferences objectAtIndex:indexPath.section] objectForKey:@"rows"] objectAtIndex:indexPath.row];
	if ([[rowDictionary objectForKey:CQPSType] isEqualToString:CQPSChildPaneSpecifier]) {
		viewController = [[CQPreferencesViewController alloc] initWithPlistNamed:[rowDictionary objectForKey:CQPSFile]];
	} else if ([[rowDictionary objectForKey:CQPSType] isEqualToString:CQPSMultiValueSpecifier]) {
		CQPreferencesListViewController *preferencesListViewController = [[CQPreferencesListViewController alloc] init];
		preferencesListViewController.allowEditing = NO;
		preferencesListViewController.items = [rowDictionary objectForKey:CQPSTitles];

		id key = [rowDictionary objectForKey:CQPSKey];
		id value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
		if (!value)
			value = [rowDictionary objectForKey:CQPSDefaultValue];
		preferencesListViewController.selectedItemIndex = [[rowDictionary objectForKey:CQPSValues] indexOfObject:value];
		preferencesListViewController.preferencesListBlock = ^(CQPreferencesListViewController *editedPreferencesListViewController) {
			id newValue = [[rowDictionary objectForKey:CQPSValues] objectAtIndex:editedPreferencesListViewController.selectedItemIndex];
			[[NSUserDefaults standardUserDefaults] setObject:newValue forKey:key];
		};

		viewController = preferencesListViewController;
	} else {
		[_selectedIndexPath release];
		_selectedIndexPath = nil;

		return;
	}

	if (viewController) {
		viewController.title = [rowDictionary objectForKey:CQPSTitle];

		[self.navigationController pushViewController:viewController animated:[UIView areAnimationsEnabled]];
	}

	[viewController release];
}
@end
