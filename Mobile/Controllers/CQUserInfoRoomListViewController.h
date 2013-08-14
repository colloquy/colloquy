//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

#import "CQTableViewController.h"

@class MVChatConnection;

@interface CQUserInfoRoomListViewController : CQTableViewController <UIActionSheetDelegate> {
	@protected
	NSArray *_rooms;
	MVChatConnection *_connection;
}
@property (nonatomic, strong) NSArray *rooms;
@property (nonatomic, strong) MVChatConnection *connection;
@end
