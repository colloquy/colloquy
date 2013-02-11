#import "CQTableViewController.h"

#import <MessageUI/MessageUI.h>

@interface CQPreferencesDisplayViewController : CQTableViewController <MFMailComposeViewControllerDelegate> {
	NSMutableArray *_preferences;
	NSIndexPath *_selectedIndexPath;
}

- (id) initWithRootPlist;

- (id) initWithPlistNamed:(NSString *) plist;
@end
