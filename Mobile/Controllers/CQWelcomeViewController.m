#import "CQWelcomeViewController.h"

#import "CQConnectionsController.h"
#import "CQHelpTopicViewController.h"
#import "CQHelpTopicsViewController.h"

#define NewConnectionsTableSection 0
#if !SYSTEM(TV) && !SYSTEM(MARZIPAN)
#define WhatsNewTableSection 1
#define HelpTableSection 2
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation CQWelcomeViewController {
#if !SYSTEM(TV) && !SYSTEM(MARZIPAN)
	CQHelpTopicsViewController *_helpTopicsController;
#endif
}

- (instancetype) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	self.title = NSLocalizedString(@"Welcome to Colloquy", @"Welcome view title");

#if !SYSTEM(TV) && !SYSTEM(MARZIPAN)
	UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Welcome", @"Welcome back button label") style:UIBarButtonItemStylePlain target:nil action:nil];
	self.navigationItem.backBarButtonItem = backButton;

	_helpTopicsController = [[CQHelpTopicsViewController alloc] init];
#endif

	return self;
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	[self.tableView hideEmptyCells];
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
	return 3;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	if (section == NewConnectionsTableSection)
		return 2;
#if !SYSTEM(TV) && !SYSTEM(MARZIPAN)
	if (section == WhatsNewTableSection)
		return 1;
	if (section == HelpTableSection)
		return 1;
#endif
	return 0;
}

- (NSString *__nullable) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	if (section == NewConnectionsTableSection)
		return NSLocalizedString(@"Getting Connected", @"Getting Connected welcome screen header");
	return nil;
}

- (NSString *__nullable) tableView:(UITableView *) tableView titleForFooterInSection:(NSInteger) section {
	if (section == NewConnectionsTableSection)
		return NSLocalizedString(@"A Colloquy Bouncer allows you to stay\nconnected and receive push notifications\nwhen Colloquy is closed on your device.", @"Colloquy bouncer welcome description");
	return nil;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView];

	if (indexPath.section == NewConnectionsTableSection) {
		if (indexPath.row == 0) {
			cell.textLabel.text = NSLocalizedString(@"Add an IRC Connection...", @"Add a IRC connection button label");
			cell.imageView.image = [UIImage imageNamed:@"server.png"];
		} else if (indexPath.row == 1) {
			cell.textLabel.text = NSLocalizedString(@"Add a Colloquy Bouncer...", @"Add a Colloquy bouncer button label");
			cell.imageView.image = [UIImage imageNamed:@"bouncer.png"];
		}
	}
#if !SYSTEM(TV) && !SYSTEM(MARZIPAN)
	else if (indexPath.section == WhatsNewTableSection && indexPath.row == 0) {
		cell.textLabel.text = NSLocalizedString(@"What's New in Colloquy", @"What's New in Colloquy button label");
		cell.imageView.image = [UIImage imageNamed:@"new.png"];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	} else if (indexPath.section == HelpTableSection && indexPath.row == 0) {
		cell.textLabel.text = NSLocalizedString(@"Help & Troubleshooting", @"Help button label");
		cell.imageView.image = [UIImage imageNamed:@"help.png"];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
#endif

	return cell;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == NewConnectionsTableSection) {
		if (indexPath.row == 0)
			[[CQConnectionsController defaultController] showConnectionCreationView:nil];
		else if (indexPath.row == 1)
			[[CQConnectionsController defaultController] showBouncerCreationView:nil];
	}
#if !SYSTEM(TV) && !SYSTEM(MARZIPAN)
	else if (indexPath.section == WhatsNewTableSection && indexPath.row == 0) {
		NSString *whatsNewContentPath = [[NSBundle mainBundle] pathForResource:@"whats-new" ofType:@"html"];
		NSString *whatsNewContent = [[NSString alloc] initWithContentsOfFile:whatsNewContentPath encoding:NSUTF8StringEncoding error:NULL];

		CQHelpTopicViewController *whatsNewController = [[CQHelpTopicViewController alloc] initWithHTMLContent:whatsNewContent];
		whatsNewController.navigationItem.rightBarButtonItem = self.navigationItem.rightBarButtonItem;
		whatsNewController.title = NSLocalizedString(@"What's New", @"What's New view title");

		[self.navigationController pushViewController:whatsNewController animated:YES];
	}
	else if (indexPath.section == HelpTableSection && indexPath.row == 0) {
		_helpTopicsController.navigationItem.rightBarButtonItem = self.navigationItem.rightBarButtonItem;
		[self.navigationController pushViewController:_helpTopicsController animated:YES];
	}
#endif
}
@end

NS_ASSUME_NONNULL_END
