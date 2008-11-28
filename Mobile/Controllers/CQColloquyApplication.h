@interface CQColloquyApplication : UIApplication <UIApplicationDelegate, UITabBarDelegate> {
	IBOutlet UIWindow *mainWindow;
	IBOutlet UITabBarController	*tabBarController;
}
+ (CQColloquyApplication *) sharedApplication;

@property (nonatomic, readonly) UITabBarController *tabBarController;
@property (nonatomic, readonly) UIWindow *mainWindow;
@end
