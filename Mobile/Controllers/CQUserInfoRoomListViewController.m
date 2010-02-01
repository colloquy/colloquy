//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

#import "CQUserInfoRoomListViewController.h"

#import "CQChatController.h"
#import "CQColloquyApplication.h"

#import <ChatCore/MVChatConnection.h>

@implementation CQUserInfoRoomListViewController
- (id) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	self.title = NSLocalizedString(@"Rooms", "Rooms view title");

	return self;
}

- (void) dealloc {
	self.tableView.dataSource = nil;
	self.tableView.delegate = nil;

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

	cell.imageView.image = [UIImage imageNamed:@"roomIconSmall.png"];
	cell.textLabel.text = [_connection chatRoomWithName:roomName].displayName;
	cell.accessibilityLabel = cell.textLabel.text;

	return cell;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.delegate = self;

	[sheet addButtonWithTitle:NSLocalizedString(@"Join Room", @"Join Room button title")];

	sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	[[CQColloquyApplication sharedApplication] showActionSheet:sheet forSender:[tableView cellForRowAtIndexPath:indexPath] animated:YES];

	[sheet release];
}

- (BOOL) tableView:(UITableView *) tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *) indexPath {
	return YES;
}

- (BOOL) tableView:(UITableView *) tableView canPerformAction:(SEL) action forRowAtIndexPath:(NSIndexPath *) indexPath withSender:(id) sender {
	return (action == @selector(copy:));
}

- (void) tableView:(UITableView *) tableView performAction:(SEL) action forRowAtIndexPath:(NSIndexPath *) indexPath withSender:(id) sender {
	NSString *roomName = [_rooms objectAtIndex:indexPath.row];

	if (action == @selector(copy:))
		[UIPasteboard generalPasteboard].string = roomName;
}

#pragma mark -

- (void) actionSheet:(UIActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];

	[self.tableView deselectRowAtIndexPath:selectedIndexPath animated:NO];

	if (buttonIndex == actionSheet.cancelButtonIndex)
		return;

	[self dismissModalViewControllerAnimated:YES];

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
