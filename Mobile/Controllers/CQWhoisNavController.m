//
//  CQWhoisNavController.m
//  Mobile Colloquy
//
//  Created by August Joki on 1/3/09.
//  Copyright 2009 Concinnous Software. All rights reserved.
//

#import "CQWhoisNavController.h"
#import "CQWhoisViewController.h"


static CQWhoisNavController *singleton = nil;

@implementation CQWhoisNavController


+ (CQWhoisNavController *)sharedInstance;
{
	@synchronized(self) {
		if (singleton == nil) {
			NSArray *items = [[NSBundle mainBundle] loadNibNamed:@"WhoisNav" owner:self options:nil];
			for (id item in items) {
				if ([item isKindOfClass:[self class]]) {
					singleton = [item retain];
					singleton.navigationBar.topItem.rightBarButtonItem.enabled = NO; // disable until refresh works properly
					break;
				}
			}
		}
	}
	return singleton;
}


- (IBAction)doneButtonPressed:(UIBarButtonItem*)sender;
{
	whoisController.user = nil;
	[self.parentViewController dismissModalViewControllerAnimated:YES];
}


- (void)setUser:(id)user;
{
	whoisController.user = user;
}

- (id)user;
{
	return whoisController.user;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}


- (void)dealloc {
	[singleton release];
    [super dealloc];
}


@end
