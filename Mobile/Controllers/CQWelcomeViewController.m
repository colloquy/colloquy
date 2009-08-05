#import "CQWelcomeViewController.h"

#import "CQConnectionsController.h"
#import "CQHelpTopicsViewController.h"
#import "UITableViewAdditions.h"

#define NewConnectionsTableSection 0
#define ScreencastTableSection 1
#define HelpTableSection 2

@implementation CQWelcomeViewController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	self.title = NSLocalizedString(@"Welcome to Colloquy", @"Welcome view title");

	UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Welcome", @"Welcome back button label") style:UIBarButtonItemStylePlain target:nil action:nil];
	self.navigationItem.backBarButtonItem = backButton;
	[backButton release];

	_helpData = [[NSMutableData alloc] initWithCapacity:4096];

	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:CQHelpTopicsURLString] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:15.];
	[NSURLConnection connectionWithRequest:request delegate:self];

	return self;
}

- (void) dealloc {
	[_help release];
	[_helpData release];

	[super dealloc];
}

#pragma mark -

- (void) connection:(NSURLConnection *) connection didReceiveData:(NSData *) data {
	[_helpData appendData:data];
}

- (void) connectionDidFinishLoading:(NSURLConnection *) connection {
	if (!_help && _helpData)
		_help = [[NSPropertyListSerialization propertyListFromData:_helpData mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:NULL] retain];

	if (!_help)
		_help = [[NSArray alloc] init];

	[_helpData release];
	_helpData = nil;
}

- (void) connection:(NSURLConnection *) connection didFailWithError:(NSError *) error {
	if (!_help)
		_help = [[NSArray alloc] init];

	[_helpData release];
	_helpData = nil;
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView {
    return 3;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	if (section == NewConnectionsTableSection)
		return 2;
	if (section == ScreencastTableSection)
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
		cell.text = NSLocalizedString(@"Add an IRC Connection...", @"Add a IRC connection button label");
		cell.image = [UIImage imageNamed:@"server.png"];
	} else if (indexPath.section == NewConnectionsTableSection && indexPath.row == 1) {
		cell.text = NSLocalizedString(@"Add a Colloquy Bouncer...", @"Add a Colloquy bouncer button label");
		cell.image = [UIImage imageNamed:@"bouncer.png"];
	} else if (indexPath.section == ScreencastTableSection && indexPath.row == 0) {
		cell.text = NSLocalizedString(@"Colloquy Screencasts", @"Screencasts button label");
		cell.image = [UIImage imageNamed:@"play.png"];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	} else if (indexPath.section == HelpTableSection && indexPath.row == 0) {
		cell.text = NSLocalizedString(@"Help & Troubleshooting", @"Help button label");
		cell.image = [UIImage imageNamed:@"help.png"];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}

    return cell;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (indexPath.section == NewConnectionsTableSection && indexPath.row == 0) {
		[self dismissModalViewControllerAnimated:YES];

		[[CQConnectionsController defaultController] performSelector:@selector(showModalNewConnectionView) withObject:nil afterDelay:0.5];
	} else if (indexPath.section == NewConnectionsTableSection && indexPath.row == 1) {
		[self dismissModalViewControllerAnimated:YES];

		[[CQConnectionsController defaultController] performSelector:@selector(showModalNewBouncerView) withObject:nil afterDelay:0.5];
	} else if (indexPath.section == HelpTableSection && indexPath.row == 0) {
		CQHelpTopicsViewController *helpTopicsController = [[CQHelpTopicsViewController alloc] initWithHelpContent:_help];
		helpTopicsController.navigationItem.rightBarButtonItem = self.navigationItem.rightBarButtonItem;

		[self.navigationController pushViewController:helpTopicsController animated:YES];

		[helpTopicsController release];
	}
}
@end
