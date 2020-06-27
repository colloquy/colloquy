//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

#import "CQUserInfoRoomListViewController.h"

#import "CQChatController.h"
#import "CQColloquyApplication.h"

#import <ChatCore/MVChatConnection.h>

NS_ASSUME_NONNULL_BEGIN

@interface CQUserInfoRoomListViewController () <CQActionSheetDelegate>
@end

@implementation CQUserInfoRoomListViewController
- (instancetype) init {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	self.title = NSLocalizedString(@"Rooms", "Rooms view title");

	return self;
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	[self.tableView hideEmptyCells];
}

#pragma mark -

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	return _rooms.count;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView];

	NSString *roomName = _rooms[indexPath.row];

	cell.imageView.image = [UIImage imageNamed:@"roomIconSmall.png"];
	cell.textLabel.text = [_connection chatRoomWithName:roomName].displayName;
	cell.accessibilityLabel = cell.textLabel.text;

	return cell;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	CQActionSheet *sheet = [[CQActionSheet alloc] init];
	sheet.delegate = self;

	if (!self.view.window.isFullscreen)
		sheet.title = _rooms[indexPath.row];

	[sheet addButtonWithTitle:NSLocalizedString(@"Join Room", @"Join Room button title")];

	sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	[[CQColloquyApplication sharedApplication] showActionSheet:sheet forSender:[tableView cellForRowAtIndexPath:indexPath] animated:YES];

}

- (BOOL) tableView:(UITableView *) tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *) indexPath {
	return YES;
}

- (BOOL) tableView:(UITableView *) tableView canPerformAction:(SEL) action forRowAtIndexPath:(NSIndexPath *) indexPath withSender:(__nullable id) sender {
	return (action == @selector(copy:));
}

- (void) tableView:(UITableView *) tableView performAction:(SEL) action forRowAtIndexPath:(NSIndexPath *) indexPath withSender:(__nullable id) sender {
#if !SYSTEM(TV)
	NSString *roomName = _rooms[indexPath.row];

	if (action == @selector(copy:))
		[UIPasteboard generalPasteboard].string = roomName;
#endif
}

#pragma mark -

- (void) actionSheet:(CQActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];

	[self.tableView deselectRowAtIndexPath:selectedIndexPath animated:NO];

	if (buttonIndex == actionSheet.cancelButtonIndex)
		return;

	[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];

	NSString *roomName = _rooms[selectedIndexPath.row];
	[[CQChatController defaultController] showChatControllerWhenAvailableForRoomNamed:roomName andConnection:_connection];
	[_connection joinChatRoomNamed:roomName];
}

#pragma mark -

- (void) setRooms:(NSArray <NSString *> *) rooms {
	_rooms = rooms;

	[self.tableView reloadData];
}
@end

NS_ASSUME_NONNULL_END
