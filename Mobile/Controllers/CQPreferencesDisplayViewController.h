#import "CQTableViewController.h"

#import <MessageUI/MessageUI.h>

NS_ASSUME_NONNULL_BEGIN

@interface CQPreferencesDisplayViewController : CQTableViewController <MFMailComposeViewControllerDelegate> {
	NSMutableArray *_preferences;
	NSIndexPath *_selectedIndexPath;
}

- (instancetype) initWithNibName:(NSString *) nibNameOrNil bundle:(NSBundle *) nibBundleOrNil NS_UNAVAILABLE;
- (instancetype) initWithStyle:(UITableViewStyle) style NS_UNAVAILABLE;
- (instancetype) initWithCoder:(NSCoder *) aDecoder NS_UNAVAILABLE;

- (instancetype) initWithRootPlist NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithPlistNamed:(NSString *) plist NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
