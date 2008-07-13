#import "CQConnectionEditViewController.h"

#import "CQPreferencesTextCell.h"

#import <ChatCore/MVChatConnection.h>

@implementation CQConnectionEditViewController
- (id) init {
	if( ! ( self = [super initWithNibName:@"ConnectionEdit" bundle:nil] ) )
		return nil;
	return self;
}

- (void) dealloc {
	[editTableView release];
	[_connection release];
	[super dealloc];
}

#pragma mark -

@synthesize connection = _connection;

- (void) setConnection:(MVChatConnection *) connection {
	id old = _connection;
	_connection = [connection retain];
	[old release];

	self.title = connection.server;

	[editTableView reloadData];
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
	return 4;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	switch( section ) {
		case 0: return 3;
		case 1: return 3;
		case 2: return 3;
		case 3: return 2;
		default: return 0;
	}
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
	switch( section ) {
		case 1: return NSLocalizedString(@"Identity", @"Identity section title");
		case 2: return NSLocalizedString(@"Authentication", @"Authentication section title");
		case 3: return NSLocalizedString(@"Automatic", @"Automatic section title");
		default: return nil;
	}

	return nil;
}

- (NSString *) tableView:(UITableView *) tableView titleForFooterInSection:(NSInteger) section {
	if( section == 2 )
		return NSLocalizedString(@"The nickname password is used to\nauthenicate with services (e.g. NickServ).", @"Nickname password section footer title");
	return nil;
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	return nil;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	CQPreferencesTextCell *cell = [[CQPreferencesTextCell alloc] init];
	cell.text = @"Test";
	cell.label = @"My Label";
	return [cell autorelease];
}
@end
