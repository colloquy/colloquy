//
//  CQWhoisNavController.h
//  Mobile Colloquy
//
//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

@class CQWhoisViewController;
@class MVChatUser;

@interface CQWhoisNavController : UINavigationController <UINavigationControllerDelegate> {
	CQWhoisViewController *_whoisViewController;
	MVChatUser *_user;
}
@property (nonatomic, retain) MVChatUser *user;

- (IBAction) close:(id) sender;
@end
