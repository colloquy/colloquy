#import "CQTableViewController.h"

#import <MessageUI/MessageUI.h>

@interface CQPreferencesDisplayViewController : CQTableViewController <MFMailComposeViewControllerDelegate> {
	NSMutableArray *_preferences;
	NSIndexPath *_selectedIndexPath;
}

- (instancetype) initWithRootPlist;

- (instancetype) initWithPlistNamed:(NSString *) plist NS_DESIGNATED_INITIALIZER;
@end
