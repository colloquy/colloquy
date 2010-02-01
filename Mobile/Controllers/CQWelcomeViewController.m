#import "CQWelcomeViewController.h"

#import "CQConnectionsController.h"
#import "CQHelpTopicViewController.h"
#import "CQHelpTopicsViewController.h"

#define NewConnectionsTableSection 0
#define WhatsNewTableSection 1
#define HelpTableSection 2

@implementation CQWelcomeViewController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	self.title = NSLocalizedString(@"Welcome to Colloquy", @"Welcome view title");

	UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Welcome", @"Welcome back button label") style:UIBarButtonItemStylePlain target:nil action:nil];
	self.navigationItem.backBarButtonItem = backButton;
	[backButton release];

	_helpTopicsController = [[CQHelpTopicsViewController alloc] init];

	return self;
}

- (void) dealloc {
	self.tableView.dataSource = nil;
	self.tableView.delegate = nil;

	[_helpTopicsController release];

	[super dealloc];
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
    return 3;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	if (section == NewConnectionsTableSection)
		return 2;
	if (section == WhatsNewTableSection)
		return 1;
	if (section == HelpTableSection)
		return 1;
	return 0;
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	if (section == NewConnectionsTableSection)
		return NSLocalizedString(@"Getting Connected", @"Getting Connected welcome screen header");
	return nil;
}

- (NSString *) tableView:(UITableView *) tableView titleForFooterInSection:(NSInteger) section {
	if (section == NewConnectionsTableSection)
		return NSLocalizedString(@"A Colloquy Bouncer allows you to stay\nconnected and receive push notifications\nwhen Colloquy is closed on your device.", @"Colloquy bouncer welcome description");
	return nil;
}

- (CGFloat) tableView:(UITableView *) tableView heightForFooterInSection:(NSInteger) section {
	if (section == NewConnectionsTableSection)
		return 75.;
	return 0.;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView];

	if (indexPath.section == NewConnectionsTableSection && indexPath.row == 0) {
		cell.textLabel.text = NSLocalizedString(@"Add an IRC Connection...", @"Add a IRC connection button label");
		cell.imageView.image = [UIImage imageNamed:@"server.png"];
	} else if (indexPath.section == NewConnectionsTableSection && indexPath.row == 1) {
		cell.textLabel.text = NSLocalizedString(@"Add a Colloquy Bouncer...", @"Add a Colloquy bouncer button label");
		cell.imageView.image = [UIImage imageNamed:@"bouncer.png"];
	} else if (indexPath.section == WhatsNewTableSection && indexPath.row == 0) {
		cell.textLabel.text = NSLocalizedString(@"What's New in Colloquy", @"What's New in Colloquy button label");
		cell.imageView.image = [UIImage imageNamed:@"new.png"];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	} else if (indexPath.section == HelpTableSection && indexPath.row == 0) {
		cell.textLabel.text = NSLocalizedString(@"Help & Troubleshooting", @"Help button label");
		cell.imageView.image = [UIImage imageNamed:@"help.png"];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}

    return cell;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == NewConnectionsTableSection && indexPath.row == 0) {
		[[CQConnectionsController defaultController] showConnectionCreationView:nil];
	} else if (indexPath.section == NewConnectionsTableSection && indexPath.row == 1) {
		[[CQConnectionsController defaultController] showBouncerCreationView:nil];
	} else if (indexPath.section == WhatsNewTableSection && indexPath.row == 0) {
		NSString *whatsNewContentPath = [[NSBundle mainBundle] pathForResource:@"whats-new" ofType:@"html"];
		NSString *whatsNewContent = [[NSString alloc] initWithContentsOfFile:whatsNewContentPath encoding:NSUTF8StringEncoding error:NULL];

		CQHelpTopicViewController *whatsNewController = [[CQHelpTopicViewController alloc] initWithHTMLContent:whatsNewContent];
		whatsNewController.navigationItem.rightBarButtonItem = self.navigationItem.rightBarButtonItem;
		whatsNewController.title = NSLocalizedString(@"What's New", @"What's New view title");

		[self.navigationController pushViewController:whatsNewController animated:YES];

		[whatsNewController release];
		[whatsNewContent release];
	} else if (indexPath.section == HelpTableSection && indexPath.row == 0) {
		_helpTopicsController.navigationItem.rightBarButtonItem = self.navigationItem.rightBarButtonItem;
		[self.navigationController pushViewController:_helpTopicsController animated:YES];
	}
}
@end
