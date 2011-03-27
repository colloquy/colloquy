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
	[_password release];

	[super dealloc];
}

#pragma mark -

- (void) savePasswordToKeychain {
	NSString *room = [_connection properNameForChatRoomNamed:self.room];
	if (room.length)
		[[CQKeychain standardKeychain] setPassword:_password forServer:_connection.uniqueIdentifier area:room];
}

- (void) loadPasswordFromKeychain {
	NSString *room = [_connection properNameForChatRoomNamed:self.room];
	id old = _password;
	_password = (room.length ? [[[CQKeychain standardKeychain] passwordForServer:_connection.uniqueIdentifier area:room] copy] : nil);
	[old release];
}

#pragma mark -

- (void) viewWillAppear:(BOOL) animated {
	[self loadPasswordFromKeychain];

	[super viewWillAppear:animated];
}

- (void) viewDidDisappear:(BOOL) animated {
	[self savePasswordToKeychain];

	[super viewDidDisappear:animated];
}

#pragma mark -

- (NSString *) room {
	return _listItemText;
}

- (NSString *) password {
	return _password;
}

#pragma mark -

- (void) listItemChanged:(CQPreferencesTextCell *) sender {
	switch (sender.tag) {
	case RoomPasswordRow: {
		id old = _password;
		_password = [sender.textField.text copy];
		[old release];
		break;
	}

	default:
		[super listItemChanged:sender];

		if (_password.length) {
			id oldPassword = [_password copy];
			[self loadPasswordFromKeychain];
			if (!_password.length) {
				id old = _password;
				_password = oldPassword;
				[old release];
			} else {
				[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:RoomPasswordRow inSection:0] withAnimation:UITableViewRowAnimationNone];
				[oldPassword release];
			}
		} else {
			[self loadPasswordFromKeychain];
			if (_password.length)
				[self.tableView updateCellAtIndexPath:[NSIndexPath indexPathForRow:RoomPasswordRow inSection:0] withAnimation:UITableViewRowAnimationNone];
		}

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
		cell = [CQPreferencesTextCell reusableTableViewCellInTableView:tableView withIdentifier:@"Secure CQPreferencesTextCell"];
		cell.textField.text = (_password ? _password : @"");
		cell.textField.placeholder = NSLocalizedString(@"Password (Optional)", @"Optional password text placeholder");
		cell.textField.secureTextEntry = YES;
		cell.textField.clearButtonMode = UITextFieldViewModeAlways;
		cell.textField.returnKeyType = UIReturnKeyDefault;
		cell.textField.keyboardType = UIKeyboardTypeASCIICapable;
		cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
		cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
		cell.tag = RoomPasswordRow;

		cell.textEditAction = @selector(listItemChanged:);

		return cell;

	default:
		return [super tableView:tableView cellForRowAtIndexPath:indexPath];
	}
}
@end
