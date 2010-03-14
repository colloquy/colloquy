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
	NSString *room = self.room;

	if (!room.length)
		return nil;

	return [[CQKeychain standardKeychain] passwordForArea:room account:_connection.uniqueIdentifier];
}

#pragma mark -

- (void) listItemChanged:(CQPreferencesTextCell *) sender {
	NSString *room = nil;
	NSString *password = nil;

	switch (sender.tag) {
	case RoomPasswordRow:
		room = self.room;
		password = sender.textField.text;

		if (!room.length)
			return;

		if (password.length)
			[[CQKeychain standardKeychain] setPassword:password forArea:room account:_connection.uniqueIdentifier];
		else [[CQKeychain standardKeychain] removePasswordForArea:room account:_connection.uniqueIdentifier];
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
