//
//  CQWhoisNavController.h
//  Mobile Colloquy
//
//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CQWhoisViewController;

@interface CQWhoisNavController : UINavigationController {
	IBOutlet CQWhoisViewController *whoisController;
}

@property(nonatomic, retain) id user;

+ (CQWhoisNavController *)sharedInstance;

- (IBAction)doneButtonPressed:(UIBarButtonItem*)sender;

@end
