//
//  CQWhoisViewController.h
//  Mobile Colloquy
//
//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MVChatUser;

@interface CQWhoisViewController : UIViewController <UITableViewDelegate, UITableViewDataSource> {
	MVChatUser *_user;
	IBOutlet UITableView *tableView;
	
	BOOL _addressResolved;
	NSString *address;
}

@property (nonatomic, retain) MVChatUser *user;

- (IBAction)refreshButtonPressed:(UIBarButtonItem*)sender;

@end
