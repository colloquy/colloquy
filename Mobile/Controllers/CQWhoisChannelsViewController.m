//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

#import "CQWhoisChannelsViewController.h"

#import "CQChatController.h"

#import <ChatCore/MVChatConnection.h>

@implementation CQWhoisChannelsViewController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;
	self.title = NSLocalizedString(@"Rooms", "Rooms view title");
	return self;
}

- (void) dealloc {
	[_connection release];
	[_rooms release];

	[super dealloc];
}

#pragma mark -

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	return _rooms.count;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView];

	NSString *roomName = [_rooms objectAtIndex:indexPath.row];

	cell.image = [UIImage imageNamed:@"roomIconSmall.png"];
	cell.text = [_connection chatRoomWithName:roomName].displayName;
	cell.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"Join %@", @"Voiceover join %@ label"), cell.text];

	return cell;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.delegate = self;

	[sheet addButtonWithTitle:NSLocalizedString(@"Join Room", @"Join Room button title")];

	sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	[sheet showInView:self.view];

	[sheet release];
}

#pragma mark -

- (void) actionSheet:(UIActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];

	[self.tableView deselectRowAtIndexPath:selectedIndexPath animated:NO];

	if (buttonIndex == actionSheet.cancelButtonIndex)
		return;

	NSString *roomName = [_rooms objectAtIndex:selectedIndexPath.row];

	[[CQChatController defaultController] showChatControllerWhenAvailableForRoomNamed:roomName andConnection:_connection];

	[_connection joinChatRoomNamed:roomName];
}

#pragma mark -

@synthesize connection = _connection;

@synthesize rooms = _rooms;

- (void) setRooms:(NSArray *) rooms {
	id old = _rooms;
	_rooms = [rooms retain];
	[old release];

	[self.tableView reloadData];
}
@end
