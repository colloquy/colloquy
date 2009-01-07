@interface CQColloquyApplication : UIApplication <UIApplicationDelegate, UITabBarDelegate> {
	IBOutlet UIWindow *mainWindow;
	IBOutlet UITabBarController	*tabBarController;
	NSDate *_launchDate;
}
+ (CQColloquyApplication *) sharedApplication;

- (BOOL) isSpecialApplicationURL:(NSURL *) url;
- (BOOL) openURL:(NSURL *) url usingBuiltInBrowser:(BOOL) openWithBrowser;

- (void) showActionSheet:(UIActionSheet *) sheet;

@property (nonatomic, readonly) NSDate *launchDate;
@property (nonatomic, readonly) UITabBarController *tabBarController;
@property (nonatomic, readonly) UIWindow *mainWindow;
@end
