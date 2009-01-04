//
//  CQWhoisChannelsViewController.h
//  Mobile Colloquy
//
//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MVChatConnection;

@interface CQWhoisChannelsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UIActionSheetDelegate> {
	IBOutlet UITableView *tableView;
	
	NSArray *_channels;
	MVChatConnection *_connection;
}

@property(nonatomic, retain) NSArray *channels;
@property(nonatomic, assign) MVChatConnection *connection;

@end
