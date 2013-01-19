#import "CQTableViewController.h"

@interface CQPreferencesViewController : CQTableViewController {
	NSMutableArray *_preferences;
}

- (id) initWithRootPlist;

- (id) initWithPlistNamed:(NSString *) plist;
@end
