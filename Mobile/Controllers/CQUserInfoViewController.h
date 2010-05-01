//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

#import "CQTableViewController.h"

@class MVChatUser;

@interface CQUserInfoViewController : CQTableViewController {
	@protected
	MVChatUser *_user;
	NSTimer *_updateTimesTimer;
	NSTimer *_updateInfoTimer;
	NSTimeInterval _idleTimeStart;
}
@property (nonatomic, retain) MVChatUser *user;

- (IBAction) showJoinedRooms:(id) sender;
- (IBAction) refreshInformation:(id) sender;
@end
