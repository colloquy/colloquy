#import "CQImportantChatMessageViewController.h"

enum {
	CQMessageSectionRecentlySent
};

@implementation CQImportantChatMessageViewController
- (id) initWithMessages:(NSArray *) messages delegate:(id <CQImportantChatMessageDelegate>) delegate {
	if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
		return nil;

	_messages = [messages copy];
	_delegate = delegate;

	return self;
}

- (void) dealloc {
	_delegate = nil;
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	self.title = NSLocalizedString(@"Recent Messages", @"Recent Messages title");
}

#pragma mark -

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
	if (section == CQMessageSectionRecentlySent)
		return _messages.count ? _messages.count : 1;
	return 0;
}

- (UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *) indexPath {
	UITableViewCell *cell = [UITableViewCell reusableTableViewCellInTableView:tableView];

	if (_messages.count) {
		cell.textLabel.text = [_messages[indexPath.row][@"message"] stringByStrippingXMLTags];
		if ([_messages[indexPath.row][@"action"] boolValue]) {
			cell.textLabel.text = [NSString stringWithFormat:@"• %@", cell.textLabel.text];
		}
	} else {
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.textLabel.text = NSLocalizedString(@"No sent messages", @"No sent messages");
	}

	return cell;
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if (!_messages.count)
		return nil;
	return indexPath;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath {
	if ([_delegate respondsToSelector:@selector(importantChatMessageViewController:didSelectMessage:isAction:)])
		[_delegate importantChatMessageViewController:self didSelectMessage:[_messages[indexPath.row][@"message"] stringByStrippingXMLTags] isAction:[_messages[indexPath.row][@"action"] boolValue]];
}
@end
