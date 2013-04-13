#import "CQChatRoomInfoViewController.h"
#import "CQChatRoomInfoDisplayViewController.h"

#import <ChatCore/MVChatRoom.h>

@implementation CQChatRoomInfoViewController
- (id) initWithRoom:(MVChatRoom *) room {
	if (!(self = [super init]))
		return nil;

	_room = [room retain];

	return self;
}

- (void) dealloc {
	[_room release];

	[super dealloc];
}

- (void) viewDidLoad {
	if (!_rootViewController) {
		CQChatRoomInfoDisplayViewController *roomInfoDisplayViewController = [[CQChatRoomInfoDisplayViewController alloc] initWithRoom:_room];
		roomInfoDisplayViewController.title = _room.displayName;
		_rootViewController = roomInfoDisplayViewController;
	}

    [super viewDidLoad];

	UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Close", @"Close button title") style:UIBarButtonItemStyleDone target:self action:@selector(close:)];
	_rootViewController.navigationItem.leftBarButtonItem = doneItem;
	[doneItem release];
}
@end
