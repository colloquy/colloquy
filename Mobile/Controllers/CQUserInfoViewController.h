//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

@class MVChatUser;

NS_ASSUME_NONNULL_BEGIN

@interface CQUserInfoViewController : UITableViewController
@property (nonatomic, strong) MVChatUser *user;

- (IBAction) showJoinedRooms:(__nullable id) sender;
- (IBAction) refreshInformation:(__nullable id) sender;
@end

NS_ASSUME_NONNULL_END
