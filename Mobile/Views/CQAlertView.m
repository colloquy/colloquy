#import "CQAlertView.h"

@implementation CQAlertView
- (void) dealloc {
	[_userInfo release];

	[super dealloc];
}

@synthesize userInfo = _userInfo;
@end
