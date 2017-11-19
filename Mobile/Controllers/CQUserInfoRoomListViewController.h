//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

@class MVChatConnection;

NS_ASSUME_NONNULL_BEGIN

@interface CQUserInfoRoomListViewController : UITableViewController
@property (nonatomic, strong) NSArray <NSString *> *rooms;
@property (nonatomic, strong) MVChatConnection *connection;
@end

NS_ASSUME_NONNULL_END
