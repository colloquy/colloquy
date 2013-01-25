#import "CQTableViewController.h"

@interface CQPreferencesDisplayViewController : CQTableViewController {
	NSMutableArray *_preferences;
	NSIndexPath *_selectedIndexPath;
}

- (id) initWithRootPlist;

- (id) initWithPlistNamed:(NSString *) plist;
@end
