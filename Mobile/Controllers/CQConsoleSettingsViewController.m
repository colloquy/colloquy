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

	switch (indexPath.row) {
	case CQConsoleSettingsRowNick:
		cell.textLabel.text = NSLocalizedString(@"Hide Nick Changes", @"Show Nick Changes cell label");
		cell.on = defaultForServer(CQConsoleHideNickKey, _connection.server);
		break;
	case CQConsoleSettingsRowTraffic:
		cell.textLabel.text = NSLocalizedString(@"Hide Room Traffic", @"Hide Room Traffic cell label");
		cell.on = defaultForServer(CQConsoleHideTrafficKey, _connection.server);
		break;
	case CQConsoleSettingsRowTopic:
		cell.textLabel.text = NSLocalizedString(@"Hide Topic Changes", @"Hide Topic Changes cell label");
		cell.on = defaultForServer(CQConsoleHideTopicKey, _connection.server);
		break;
	case CQConsoleSettingsRowMode:
		cell.textLabel.text = NSLocalizedString(@"Hide Mode Changes", @"Hide Mode Changes cell label");
		cell.on = defaultForServer(CQConsoleHideModeKey, _connection.server);
		break;
	case CQConsoleSettingsRowMessage:
		cell.textLabel.text = NSLocalizedString(@"Hide Messages", @"Hide Messages cell label");
		cell.on = defaultForServer(CQConsoleHideMessagesKey, _connection.server);
		break;
	case CQConsoleSettingsRowNumeric:
		cell.textLabel.text = NSLocalizedString(@"Hide Server Traffic", @"Hide Server Traffic cell label");
		cell.on = defaultForServer(CQConsoleHideTrafficKey, _connection.server);
		break;
	case CQConsoleSettingsRowCTCP:
		cell.textLabel.text = NSLocalizedString(@"Hide CTCP Messages", @"Hide CTCP Messages cell label");
		cell.on = defaultForServer(CQConsoleHideCtcpKey, _connection.server);
		break;
	case CQConsoleSettingsRowPing:
		cell.textLabel.text = NSLocalizedString(@"Hide PING and PONGs", @"Hide PING and PONGs cell label");
		cell.on = defaultForServer(CQConsoleHidePingKey, _connection.server);
		break;
	case CQConsoleSettingsRowUnknown:
		cell.textLabel.text = NSLocalizedString(@"Hide Other Messages", @"Hide Other Messages cell label");
		cell.on = defaultForServer(CQConsoleHideUnknownKey, _connection.server);
		break;
	case CQConsoleSettingsRowSocket:
		cell.textLabel.text = NSLocalizedString(@"Hide Socket Traffic", @"Hide Socket Traffic cell label");
		cell.on = defaultForServer(CQConsoleHideSocketKey, _connection.server);
		break;
	}

	return cell;
}
@end
