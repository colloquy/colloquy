#import "CQChatRoomInfoViewController.h"
#import "CQChatRoomInfoDisplayViewController.h"

#import <ChatCore/MVChatRoom.h>

NS_ASSUME_NONNULL_BEGIN

@implementation CQChatRoomInfoViewController {
	MVChatRoom *_room;
	CQChatRoomInfo _infoType;
}

- (instancetype) initWithRoom:(MVChatRoom *) room showingInfoType:(CQChatRoomInfo) infoType {
	CQChatRoomInfoDisplayViewController *roomInfoDisplayViewController = [[CQChatRoomInfoDisplayViewController alloc] initWithRoom:_room showingInfoType:_infoType];

	if (!(self = [super initWithRootViewController:roomInfoDisplayViewController]))
		return nil;

	_room = room;
	_infoType = infoType;
	_rootViewController = roomInfoDisplayViewController;
	roomInfoDisplayViewController.title = _room.displayName;

	return self;
}


- (void) viewDidLoad {
	if (!_rootViewController) {
	}

	[super viewDidLoad];

	UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Close", @"Close button title") style:UIBarButtonItemStyleDone target:self action:@selector(close:)];
	_rootViewController.navigationItem.leftBarButtonItem = doneItem;
}
@end

NS_ASSUME_NONNULL_END
