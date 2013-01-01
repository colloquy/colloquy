#import "CQConsoleSettingsViewController.h"

#import "CQConsoleController.h"

#import "CQPreferencesSwitchCell.h"

#import "MVChatConnection.h"

enum {
	CQConsoleSettingsRowNick,
	CQConsoleSettingsRowTraffic,
	CQConsoleSettingsRowTopic,
	CQConsoleSettingsRowMessage,
	CQConsoleSettingsRowMode,
	CQConsoleSettingsRowNumeric,
	CQConsoleSettingsRowCTCP,
	CQConsoleSettingsRowPing,
	CQConsoleSettingsRowUnknown,
	CQConsoleSettingsRowSocket,
	CQConsoleSettingsRowCount
};

MVInline void setDefaultForServer(NSString *defaultName, NSString *serverName, BOOL value) {
	[[NSUserDefaults standardUserDefaults] setBool:value forKey:[NSString stringWithFormat:@"CQConsoleDisplay%@-%@", defaultName, serverName]];
}

@implementation CQConsoleSettingsViewController
- (id) initWithConnection:(MVChatConnection *) connection {
	if (!(self = [super init]))
		return nil;

	_connection = [connection retain];

	return self;
}

- (void) dealloc {
	[_connection release];

	[super dealloc];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	self.tableView.dataSource = self;
	self.tableView.delegate = self;

	self.navigationItem.title = NSLocalizedString(@"Settings", @"Settings view title");
}

#pragma mark -

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	return CQConsoleSettingsRowCount;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	CQPreferencesSwitchCell *cell = [CQPreferencesSwitchCell reusableTableViewCellInTableView:tableView];
	cell.switchControl.tag = indexPath.row;
	cell.switchAction = @selector(settingChanged:);

	switch (indexPath.row) {
	case CQConsoleSettingsRowNick:
		cell.textLabel.text = NSLocalizedString(@"Nick Changes", @"Show Nick Changes cell label");
		cell.on = defaultForServer(CQConsoleHideNickKey, _connection.server);
		break;
	case CQConsoleSettingsRowTraffic:
		cell.textLabel.text = NSLocalizedString(@"Room Traffic", @"Room Traffic cell label");
		cell.on = defaultForServer(CQConsoleHideTrafficKey, _connection.server);
		break;
	case CQConsoleSettingsRowTopic:
		cell.textLabel.text = NSLocalizedString(@"Topic Changes", @"Topic Changes cell label");
		cell.on = defaultForServer(CQConsoleHideTopicKey, _connection.server);
		break;
	case CQConsoleSettingsRowMode:
		cell.textLabel.text = NSLocalizedString(@"Mode Changes", @"Mode Changes cell label");
		cell.on = defaultForServer(CQConsoleHideModeKey, _connection.server);
		break;
	case CQConsoleSettingsRowMessage:
		cell.textLabel.text = NSLocalizedString(@"Messages", @"Messages cell label");
		cell.on = defaultForServer(CQConsoleHideMessagesKey, _connection.server);
		break;
	case CQConsoleSettingsRowNumeric:
		cell.textLabel.text = NSLocalizedString(@"Server Traffic", @"Server Traffic cell label");
		cell.on = defaultForServer(CQConsoleHideTrafficKey, _connection.server);
		break;
	case CQConsoleSettingsRowCTCP:
		cell.textLabel.text = NSLocalizedString(@"CTCP Messages", @"CTCP Messages cell label");
		cell.on = defaultForServer(CQConsoleHideCtcpKey, _connection.server);
		break;
	case CQConsoleSettingsRowPing:
		cell.textLabel.text = NSLocalizedString(@"PING and PONGs", @"PING and PONGs cell label");
		cell.on = defaultForServer(CQConsoleHidePingKey, _connection.server);
		break;
	case CQConsoleSettingsRowUnknown:
		cell.textLabel.text = NSLocalizedString(@"Other Messages", @"Other Messages cell label");
		cell.on = defaultForServer(CQConsoleHideUnknownKey, _connection.server);
		break;
	case CQConsoleSettingsRowSocket:
		cell.textLabel.text = NSLocalizedString(@"Socket Traffic", @"Socket Traffic cell label");
		cell.on = defaultForServer(CQConsoleHideSocketKey, _connection.server);
		break;
	}

	return cell;
}

#pragma mark -

- (void) settingChanged:(CQPreferencesSwitchCell *) sender {
	switch (sender.switchControl.tag) {
	case CQConsoleSettingsRowNick:
		setDefaultForServer(CQConsoleHideNickKey, _connection.server, sender.on);
		break;
	case CQConsoleSettingsRowTraffic:
		setDefaultForServer(CQConsoleHideTrafficKey, _connection.server, sender.on);
		break;
	case CQConsoleSettingsRowTopic:
		setDefaultForServer(CQConsoleHideTopicKey, _connection.server, sender.on);
		break;
	case CQConsoleSettingsRowMode:
		setDefaultForServer(CQConsoleHideModeKey, _connection.server, sender.on);
		break;
	case CQConsoleSettingsRowMessage:
		setDefaultForServer(CQConsoleHideMessagesKey, _connection.server, sender.on);
		break;
	case CQConsoleSettingsRowNumeric:
		setDefaultForServer(CQConsoleHideNumericKey, _connection.server, sender.on);
		break;
	case CQConsoleSettingsRowCTCP:
		setDefaultForServer(CQConsoleHideCtcpKey, _connection.server, sender.on);
		break;
	case CQConsoleSettingsRowPing:
		setDefaultForServer(CQConsoleHidePingKey, _connection.server, sender.on);
		break;
	case CQConsoleSettingsRowUnknown:
		setDefaultForServer(CQConsoleHideUnknownKey, _connection.server, sender.on);
		break;
	case CQConsoleSettingsRowSocket:
		setDefaultForServer(CQConsoleHideSocketKey, _connection.server, sender.on);
		break;
	}
}
@end
