#import "CQTableViewController.h"

#import <MessageUI/MessageUI.h>

@interface CQPreferencesDisplayViewController : CQTableViewController <MFMailComposeViewControllerDelegate> {
	NSMutableArray *_preferences;
	NSIndexPath *_selectedIndexPath;
}

- (instancetype) initWithNibName:(NSString *) nibNameOrNil bundle:(NSBundle *) nibBundleOrNil NS_UNAVAILABLE;
- (instancetype) initWithStyle:(UITableViewStyle) style NS_UNAVAILABLE;
- (instancetype) initWithCoder:(NSCoder *) aDecoder NS_UNAVAILABLE;

- (instancetype) initWithRootPlist;
- (instancetype) initWithPlistNamed:(NSString *) plist NS_DESIGNATED_INITIALIZER;
@end
