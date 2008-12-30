@interface CQColloquyApplication : UIApplication <UIApplicationDelegate, UITabBarDelegate> {
	IBOutlet UIWindow *mainWindow;
	IBOutlet UITabBarController	*tabBarController;
}
+ (CQColloquyApplication *) sharedApplication;

- (BOOL) isSpecialApplicationURL:(NSURL *) url;
- (BOOL) openURL:(NSURL *) url usingBuiltInBrowser:(BOOL) openWithBrowser;

@property (nonatomic, readonly) UITabBarController *tabBarController;
@property (nonatomic, readonly) UIWindow *mainWindow;
@end
