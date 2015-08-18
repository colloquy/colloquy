//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

#import "CQTableViewController.h"

@class MVChatUser;

NS_ASSUME_NONNULL_BEGIN

@interface CQUserInfoViewController : CQTableViewController {
	@protected
	MVChatUser *_user;
	NSTimer *_updateTimesTimer;
	NSTimer *_updateInfoTimer;
	NSTimeInterval _idleTimeStart;
}
@property (nonatomic, strong) MVChatUser *user;

- (IBAction) showJoinedRooms:(__nullable id) sender;
- (IBAction) refreshInformation:(__nullable id) sender;
@end

NS_ASSUME_NONNULL_END
