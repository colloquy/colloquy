#import "CQConnectionAdvancedEditController.h"

#import "CQConnectionsController.h"
#import "CQPreferencesSwitchCell.h"
#import "CQPreferencesListViewController.h"
#import "CQPreferencesTextCell.h"

#import <ChatCore/MVChatConnection.h>

#define SettingsTableSection 0
#define AuthenticationTableSection 1
#define IdentitiesTableSection 2
#define AutomaticTableSection 3
#define EncodingsTableSection 4

static inline __attribute__((always_inline)) BOOL isDefaultValue(NSString *string) {
	return [string isEqualToString:@"<<default>>"];
}

static inline __attribute__((always_inline)) BOOL isPlaceholderValue(NSString *string) {
	return [string isEqualToString:@"<<placeholder>>"];
}

static inline __attribute__((always_inline)) NSString *currentPreferredNickname(MVChatConnection *connection) {
	NSString *preferredNickname = connection.preferredNickname;
	return (isDefaultValue(preferredNickname) ? [MVChatConnection defaultNickname] : preferredNickname);
}

#pragma mark -

@implementation CQConnectionAdvancedEditController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	self.title = NSLocalizedString(@"Advanced", @"Advanced view title");

	return self;
}

- (void) dealloc {
	[_connection release];

	[super dealloc];
}

#pragma mark -

- (void) viewWillAppear:(BOOL) animated {
	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:IdentitiesTableSection] withAnimation:UITableViewRowAnimationNone];
	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:AutomaticTableSection] withAnimation:UITableViewRowAnimationNone];
	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:EncodingsTableSection] withAnimation:UITableViewRowAnimationNone];

	[super viewWillAppear:animated];
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	[self.tableView endEditing:YES];
}

#pragma mark -

@synthesize newConnection = _newConnection;

@synthesize connection = _connection;

- (void) setConnection:(MVChatConnection *) connection {
	id old = _connection;
	_connection = [connection retain];
	[old release];

	[self.tableView setContentOffset:CGPointZero animated:NO];
	[self.tableView reloadData];
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	return 5;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	switch (section) {
		case SettingsTableSection: return 2;
		case AuthenticationTableSection: return 3;
		case IdentitiesTableSection: return 1;
		case AutomaticTableSection: return 1;
		case EncodingsTableSection: return 1;
		default: return 0;
	}
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	switch (section) {
		case SettingsTableSection: return NSLocalizedString(@"Connection Settings", @"Connection Settings section title");
		case AuthenticationTableSection: return NSLocalizedString(@"Authentication", @"Authentication section title");
		default: return nil;
	}
}

- (CGFloat) tableView:(UITableView *) tableView heightForFooterInSection:(NSInteger) section {
	if (section == AuthenticationTableSection)
		return 50.;
	return 0.;
}

- (NSString *) tableView:(UITableView *) tableView titleForFooterInSection:(NSInteger) section {
	if (section == AuthenticationTableSection)
		return NSLocalizedString(@"The nickname password is used to\nauthenticate with services (e.g. NickServ).", @"Authentication section footer title");
	return nil;
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == IdentitiesTableSection && indexPath.row == 0)
		return indexPath;
	if (indexPath.section == AutomaticTableSection && indexPath.row == 0)
		return indexPath;
	if (indexPath.section == EncodingsTableSection && indexPath.row == 0)
		return indexPath;
	return nil;
}

static NSString *localizedNameOfStringEncoding(NSStringEncoding encoding) {
	NSString *result = [NSString localizedNameOfStringEncoding:encoding];
	if (result.length)
		return result;

	switch (encoding) {
	case NSUTF8StringEncoding:
		return NSLocalizedString(@"Unicode (UTF-8)", "Encoding name");
	case NSASCIIStringEncoding:
		return NSLocalizedString(@"Western (ASCII)", "Encoding name");
	case NSISOLatin1StringEncoding:
		return NSLocalizedString(@"Western (ISO Latin 1)", "Encoding name");
	case 0x80000203:
		return NSLocalizedString(@"Western (ISO Latin 3)", "Encoding name");
	case 0x8000020f:
		return NSLocalizedString(@"Western (ISO Latin 9)", "Encoding name");
	case NSMacOSRomanStringEncoding:
		return NSLocalizedString(@"Western (Mac OS Roman)", "Encoding name");
	case NSWindowsCP1252StringEncoding:
		return NSLocalizedString(@"Western (Windows Latin 1)", "Encoding name");
	case 0x8000020d:
		return NSLocalizedString(@"Baltic Rim (ISO Latin 7)", "Encoding name");
	case 0x80000507:
		return NSLocalizedString(@"Baltic Rim (Windows)", "Encoding name");
	case NSISOLatin2StringEncoding:
		return NSLocalizedString(@"Central European (ISO Latin 2)", "Encoding name");
	case 0x80000204:
		return NSLocalizedString(@"Central European (ISO Latin 4)", "Encoding name");
	case 0x8000001d:
		return NSLocalizedString(@"Central European (Mac OS)", "Encoding name");
	case NSWindowsCP1250StringEncoding:
		return NSLocalizedString(@"Central European (Windows Latin 2)", "Encoding name");
	case 0x80000a02:
		return NSLocalizedString(@"Cyrillic (KOI8-R)", "Encoding name");
	case 0x80000205:
		return NSLocalizedString(@"Cyrillic (ISO 8859-5)", "Encoding name");
	case 0x80000007:
		return NSLocalizedString(@"Cyrillic (Mac OS)", "Encoding name");
	case NSWindowsCP1251StringEncoding:
		return NSLocalizedString(@"Cyrillic (Windows)", "Encoding name");
	case 0x80000207:
		return NSLocalizedString(@"Greek (ISO 8859-7)", "Encoding name");
	case 0x80000006:
		return NSLocalizedString(@"Greek (Mac OS)", "Encoding name");
	case NSWindowsCP1253StringEncoding:
		return NSLocalizedString(@"Greek (Windows)", "Encoding name");
	case 0x80000a01:
		return NSLocalizedString(@"Japanese (Shift JIS)", "Encoding name");
	case NSISO2022JPStringEncoding:
		return NSLocalizedString(@"Japanese (ISO 2022-JP)", "Encoding name");
	case NSJapaneseEUCStringEncoding:
		return NSLocalizedString(@"Japanese (EUC)", "Encoding name");
	case 0x80000001:
		return NSLocalizedString(@"Japanese (Mac OS)", "Encoding name");
	case NSShiftJISStringEncoding:
		return NSLocalizedString(@"Japanese (Windows, DOS)", "Encoding name");
	case 0x80000632:
		return NSLocalizedString(@"Chinese (GB 18030)", "Encoding name");
	case 0x80000930:
		return NSLocalizedString(@"Simplified Chinese (EUC)", "Encoding name");
	case 0x80000019:
		return NSLocalizedString(@"Simplified Chinese (Mac OS)", "Encoding name");
	case 0x80000421:
		return NSLocalizedString(@"Simplified Chinese (Windows, DOS)", "Encoding name");
	case 0x80000a03:
		return NSLocalizedString(@"Traditional Chinese (Big 5)", "Encoding name");
	case 0x80000a06:
		return NSLocalizedString(@"Traditional Chinese (Big 5 HKSCS)", "Encoding name");
	case 0x80000931:
		return NSLocalizedString(@"Traditional Chinese (EUC)", "Encoding name");
	case 0x80000002:
		return NSLocalizedString(@"Traditional Chinese (Mac OS)", "Encoding name");
	case 0x80000423:
		return NSLocalizedString(@"Traditional Chinese (Windows, DOS)", "Encoding name");
	case 0x80000940:
		return NSLocalizedString(@"Korean (EUC)", "Encoding name");
	case 0x80000003:
		return NSLocalizedString(@"Korean (Mac OS)", "Encoding name");
	case 0x80000422:
		return NSLocalizedString(@"Korean (Windows, DOS)", "Encoding name");
	case 0x8000020b:
		return NSLocalizedString(@"Thai (ISO 8859-11)", "Encoding name");
	case 0x80000015:
		return NSLocalizedString(@"Thai (Mac OS)", "Encoding name");
	case 0x8000041d:
		return NSLocalizedString(@"Thai (Windows, DOS)", "Encoding name");
	case 0x80000208:
		return NSLocalizedString(@"Hebrew (ISO 8859-8)", "Encoding name");
	case 0x80000505:
		return NSLocalizedString(@"Hebrew (Windows)", "Encoding name");
	case 0x80000206:
		return NSLocalizedString(@"Arabic (ISO 8859-6)", "Encoding name");
	case 0x80000506:
		return NSLocalizedString(@"Arabic (Windows)", "Encoding name");
	}

	NSCAssert(NO, @"Should not reach this point.");
	return @"";
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == IdentitiesTableSection && indexPath.row == 0) {
		CQPreferencesListViewController *listViewController = [[CQPreferencesListViewController alloc] init];

		listViewController.title = NSLocalizedString(@"Nicknames", @"Nicknames view title");
		listViewController.items = _connection.alternateNicknames;
		listViewController.addItemLabelText = NSLocalizedString(@"Add nickname", @"Add nickname label");
		listViewController.noItemsLabelText = NSLocalizedString(@"No nicknames", @"No nicknames label");
		listViewController.editViewTitle = NSLocalizedString(@"Edit Nickname", @"Edit Nickname view title");
		listViewController.editPlaceholder = NSLocalizedString(@"Nickname", @"Nickname placeholder");

		listViewController.target = self;
		listViewController.action = @selector(alternateNicknamesChanged:);

		[self.view endEditing:YES];

		[self.navigationController pushViewController:listViewController animated:YES];

		[listViewController release];

		return;
	}

	if (indexPath.section == AutomaticTableSection && indexPath.row == 0) {
		CQPreferencesListViewController *listViewController = [[CQPreferencesListViewController alloc] init];

		listViewController.title = NSLocalizedString(@"Commands", @"Commands view title");
		listViewController.items = _connection.automaticCommands;
		listViewController.addItemLabelText = NSLocalizedString(@"Add command", @"Add command label");
		listViewController.noItemsLabelText = NSLocalizedString(@"No commands", @"No commands label");
		listViewController.editViewTitle = NSLocalizedString(@"Edit Command", @"Edit Command view title");
		listViewController.editPlaceholder = NSLocalizedString(@"Command", @"Command placeholder");

		listViewController.target = self;
		listViewController.action = @selector(automaticCommandsChanged:);

		[self.view endEditing:YES];

		[self.navigationController pushViewController:listViewController animated:YES];

		[listViewController release];

		return;
	}

	if (indexPath.section == EncodingsTableSection) {
		CQPreferencesListViewController *listViewController = [[CQPreferencesListViewController alloc] init];

		NSUInteger selectedEncodingIndex = 0;
		NSMutableArray *encodings = [[NSMutableArray alloc] init];
		const NSStringEncoding *supportedEncodings = [_connection supportedStringEncodings];
		for (unsigned i = 0; supportedEncodings[i]; ++i) {
			NSStringEncoding encoding = supportedEncodings[i];
			[encodings addObject:localizedNameOfStringEncoding(encoding)];
			if (encoding == _connection.encoding)
				selectedEncodingIndex = i;
		}

		listViewController.title = NSLocalizedString(@"Encoding", @"Encoding view title");
		listViewController.allowEditing = NO;
		listViewController.items = encodings;
		listViewController.selectedItemIndex = selectedEncodingIndex;

		listViewController.target = self;
		listViewController.action = @selector(encodingChanged:);

		[self.view endEditing:YES];

		[self.navigationController pushViewController:listViewController animated:YES];

		[listViewController release];
		[encodings release];

		return;
	}
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == SettingsTableSection) {
		if (indexPath.row == 0) {
			CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

			unsigned short defaultPort = (_connection.secure ? 994 : 6667);

			cell.target = self;
			cell.textEditAction = @selector(serverPortChanged:);
			cell.label = NSLocalizedString(@"Server Port", @"Server Port connection setting label");
			cell.text = (_connection.serverPort == defaultPort ? @"" : [NSString stringWithFormat:@"%hu", _connection.serverPort]);
			cell.textField.placeholder = [NSString stringWithFormat:@"%hu", defaultPort];
			if (_connection.directConnection) {
				cell.textField.keyboardType = UIKeyboardTypeNumberPad;
				cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			} else {
				cell.enabled = NO;
			}

			cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Server Port: %hu", @"Voiceover server port label"), _connection.serverPort];

			return cell;
		} else if (indexPath.row == 1) {
			CQPreferencesSwitchCell *cell = [CQPreferencesSwitchCell reusableTableViewCellInTableView:tableView];

			cell.target = self;
			cell.switchAction = @selector(secureChanged:);
			cell.label = NSLocalizedString(@"Use SSL", @"Use SSL connection setting label");
			cell.on = _connection.secure;
			cell.switchControl.enabled = _connection.directConnection;

			if (_connection.secure)
				cell.accessibilityLabel = NSLocalizedString(@"Use SSL: On", @"Voiceover use SSL on label");
			else cell.accessibilityLabel = NSLocalizedString(@"Use SSL: Off", @"Voiceover use SSL off label");

			return cell;
		}
	} else if (indexPath.section == AuthenticationTableSection) {
		CQPreferencesTextCell *cell = nil;

		if (indexPath.row == 0) {
			cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

			cell.textEditAction = @selector(usernameChanged:);
			cell.label = NSLocalizedString(@"Username", @"Username connection setting label");
			cell.text = (isDefaultValue(_connection.username) ? @"" : _connection.username);
			cell.textField.placeholder = [MVChatConnection defaultUsernameWithNickname:currentPreferredNickname(_connection)];
			if (_connection.directConnection) {
				cell.textField.keyboardType = UIKeyboardTypeASCIICapable;
				cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
				cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
			} else {
				cell.enabled = NO;
			}

			cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Username: %@", @"Voiceover username label"), (cell.text.length ? cell.text : cell.textField.placeholder)];
		} else if (indexPath.row == 1) {
			cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView withIdentifier:@"Secure CQPreferencesTextCell"];

			cell.textEditAction = @selector(passwordChanged:);
			cell.label = NSLocalizedString(@"Password", @"Password connection setting label");
			cell.text = _connection.password;
			cell.textField.placeholder = NSLocalizedString(@"Optional", @"Optional connection setting placeholder");
			cell.textField.secureTextEntry = YES;
			if (_connection.directConnection) {
				cell.textField.keyboardType = UIKeyboardTypeASCIICapable;
				cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
				cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
				cell.accessibilityHint = NSLocalizedString(@"Optional", @"Voiceover optional label");
			} else {
				cell.enabled = NO;
			}

			cell.accessibilityLabel = NSLocalizedString(@"Connection password.", @"Voiceover connection password label");
			cell.accessibilityHint = NSLocalizedString(@"Optional", @"Voiceover optional label");
		} else if (indexPath.row == 2) {
			cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView withIdentifier:@"Secure CQPreferencesTextCell"];

			cell.textEditAction = @selector(nicknamePasswordChanged:);
			cell.label = NSLocalizedString(@"Nick Pass.", @"Nickname Password connection setting label");
			cell.text = _connection.nicknamePassword;
			cell.textField.placeholder = NSLocalizedString(@"Optional", @"Optional connection setting placeholder");
			cell.textField.secureTextEntry = YES;
			cell.textField.keyboardType = UIKeyboardTypeASCIICapable;
			cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
			cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;

			cell.accessibilityLabel = NSLocalizedString(@"Nickname password.", @"Voiceover nickname password label");
 			cell.accessibilityHint = NSLocalizedString(@"Optional", @"Voiceover optional label");
		}

		cell.target = self;

		return cell;
	} else if (indexPath.section == IdentitiesTableSection && indexPath.row == 0) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

		if (_connection.alternateNicknames.count)
			cell.text = [_connection.alternateNicknames componentsJoinedByString:@", "];

		if (_connection.alternateNicknames.count)
			cell.text = [_connection.alternateNicknames componentsJoinedByString:@", "];
		else cell.textField.placeholder = [NSString stringWithFormat:@"%@_, %1$@__, %1$@___, %1$@____, %1$@_____", currentPreferredNickname(_connection)];

		cell.label = NSLocalizedString(@"Alt. Nicknames", @"Alt. Nicknames connection setting label");
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

		cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Alternate Nicknames: %@", @"Voiceover alternate nicknames label"), (cell.text.length ? cell.text : cell.textField.placeholder)];
		cell.accessibilityHint = NSLocalizedString(@"Optional", @"Voiceover optional label");

		return cell;
	} else if (indexPath.section == AutomaticTableSection && indexPath.row == 0) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

		cell.label = NSLocalizedString(@"Auto Commands", @"Auto Commands connection setting label");
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

		NSArray *commands = _connection.automaticCommands;
		if (commands.count) cell.text = [NSString stringWithFormat:@"%u", commands.count];
		else cell.text = NSLocalizedString(@"None", @"None label");

		if (commands.count)
			cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Automatic Commands: %u commands", @"Voiceover automatic commands label"), commands.count];
		else cell.accessibilityLabel = NSLocalizedString(@"Automatic Commands: None", @"Voiceover automatic commands none label");

		return cell;
	} else if (indexPath.section == EncodingsTableSection && indexPath.row == 0) {
		CQPreferencesTextCell *cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];

		cell.label = NSLocalizedString(@"Encoding", @"Encoding connection setting label");
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.text = localizedNameOfStringEncoding(_connection.encoding);

		cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Encoding: %@", @"Voiceover encoding label"), cell.text];

		return cell;
	}

	NSAssert(NO, @"Should not reach this point.");
	return nil;
}

#pragma mark -

- (void) serverPortChanged:(CQPreferencesTextCell *) sender {
	NSUInteger newPort = [sender.text integerValue];
	if (newPort)
		_connection.serverPort = (newPort % 65536);

	unsigned short defaultPort = (_connection.secure ? 994 : 6667);
	sender.text = (_connection.serverPort == defaultPort ? @"" : [NSString stringWithFormat:@"%hu", _connection.serverPort]);
}

- (void) secureChanged:(CQPreferencesSwitchCell *) sender {
	_connection.secure = sender.on;

	if (_connection.secure && _connection.serverPort == 6667)
		_connection.serverPort = 994;
	else if (!_connection.secure && _connection.serverPort == 994)
		_connection.serverPort = 6667;

	[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:SettingsTableSection] withAnimation:UITableViewRowAnimationNone];
}

- (void) usernameChanged:(CQPreferencesTextCell *) sender {
	if (sender.text.length)
		_connection.username = sender.text;
	else _connection.username = (_newConnection ? @"<<default>>" : sender.textField.placeholder);

	sender.text = (isDefaultValue(_connection.username) ? @"" : _connection.username);
}

- (void) passwordChanged:(CQPreferencesTextCell *) sender {
	_connection.password = sender.text;
}

- (void) nicknamePasswordChanged:(CQPreferencesTextCell *) sender {
	_connection.nicknamePassword = sender.text;
}

- (void) alternateNicknamesChanged:(CQPreferencesListViewController *) sender {
	_connection.alternateNicknames = sender.items;
}

- (void) automaticCommandsChanged:(CQPreferencesListViewController *) sender {
	_connection.automaticCommands = sender.items;
}

- (void) encodingChanged:(CQPreferencesListViewController *) sender {
	NSStringEncoding encoding = [_connection supportedStringEncodings][sender.selectedItemIndex];
	_connection.encoding = encoding;
}
@end
