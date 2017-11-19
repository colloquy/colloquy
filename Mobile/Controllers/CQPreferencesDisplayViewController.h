NS_ASSUME_NONNULL_BEGIN

@interface CQPreferencesDisplayViewController : UITableViewController
- (instancetype) initWithNibName:(NSString *__nullable) nibNameOrNil bundle:(NSBundle *__nullable) nibBundleOrNil NS_UNAVAILABLE;
- (instancetype) initWithStyle:(UITableViewStyle) style NS_UNAVAILABLE;
- (instancetype) initWithCoder:(NSCoder *) aDecoder NS_UNAVAILABLE;

- (instancetype) initWithRootPlist NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithPlistNamed:(NSString *) plist NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
