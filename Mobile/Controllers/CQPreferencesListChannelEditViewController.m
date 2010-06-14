#import "CQPreferencesListChannelEditViewController.h"

#import "CQPreferencesTextCell.h"
#import "CQKeychain.h"

#import <ChatCore/MVChatConnection.h>

#define RoomPasswordRow 1

@interface CQPreferencesListEditViewController (Private)
- (void) listItemChanged:(CQPreferencesTextCell *) sender;
@end

@interface CQPreferencesListChannelEditViewController (Private)
@property (nonatomic, readonly) NSString *room;
@property (nonatomic, readonly) NSString *password;
@end

@implementation CQPreferencesListChannelEditViewController
@synthesize connection = _connection;

- (void) dealloc {
	[_connection release];
	
	[super dealloc];
}

#pragma mark -

- (NSString *) room {
	return _listItemText;
}

- (NSString *) password {
	NSString *room = [_connection properNameForChatRoomNamed:self.room];

	if (!room.length)
		return nil;

	return [[CQKeychain standardKeychain] passwordForServer:_connection.uniqueIdentifier area:room];
}

#pragma mark -

- (void) listItemChanged:(CQPreferencesTextCell *) sender {
	NSString *room = nil;
	NSString *password = nil;

	switch (sender.tag) {
	case RoomPasswordRow:
		room = [_connection properNameForChatRoomNamed:self.room];
		password = sender.textField.text;

		if (!room.length)
			return;

		[[CQKeychain standardKeychain] setPassword:password forServer:_connection.uniqueIdentifier area:room];
		break;
	default:
		[super listItemChanged:sender];
		break;
	}
}

#pragma mark -

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	return 2;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	CQPreferencesTextCell *cell = nil;

	switch (indexPath.row) {
	case RoomPasswordRow:
		cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView];
		cell.textField.text = self.password;
		cell.textField.placeholder = NSLocalizedString(@"Room Key (optional)", @"Room Key (optional) text placeholder");
		cell.textField.secureTextEntry = YES;
		cell.textField.clearButtonMode = UITextFieldViewModeAlways;
		cell.textField.returnKeyType = UIReturnKeyDefault;
		cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
		cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
		cell.tag = RoomPasswordRow;

		cell.target = self;
		cell.textEditAction = @selector(listItemChanged:);

		return cell;
	default:
		return [super tableView:tableView cellForRowAtIndexPath:indexPath];
	}
}
@end
