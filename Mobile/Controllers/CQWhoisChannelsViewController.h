//  CQWhoisChannelsViewController.h
//  Mobile Colloquy
//
//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

@class MVChatConnection;

@interface CQWhoisChannelsViewController : UITableViewController <UIActionSheetDelegate> {
	NSArray *_rooms;
	MVChatConnection *_connection;
}
@property (nonatomic, retain) NSArray *rooms;
@property (nonatomic, retain) MVChatConnection *connection;
@end
