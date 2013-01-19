#import "CQTableViewController.h"

@interface CQPreferencesViewController : CQTableViewController {
	NSMutableArray *_preferences;
	NSIndexPath *_selectedIndexPath;
}

- (id) initWithRootPlist;

- (id) initWithPlistNamed:(NSString *) plist;
@end
