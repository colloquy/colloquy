@protocol CQBrowserViewControllerDelegate;

extern NSString *CQColloquyApplicationDidRecieveDeviceTokenNotification;

@interface CQColloquyApplication : UIApplication <UIApplicationDelegate, UITabBarDelegate> {
	@protected
	IBOutlet UIWindow *mainWindow;
	IBOutlet UITabBarController	*tabBarController;
	NSDate *_launchDate;
	NSString *_deviceToken;
	NSUInteger _networkIndicatorStack;
	BOOL _showingTabBar;
}
+ (CQColloquyApplication *) sharedApplication;

- (void) showHelp;

- (BOOL) isSpecialApplicationURL:(NSURL *) url;

- (BOOL) openURL:(NSURL *) url usingBuiltInBrowser:(BOOL) openWithBrowser;
- (BOOL) openURL:(NSURL *) url usingBuiltInBrowser:(BOOL) openWithBrowser withBrowserDelegate:(id <CQBrowserViewControllerDelegate>) delegate;

- (void) showActionSheet:(UIActionSheet *) sheet;

- (void) hideTabBarWithTransition:(BOOL) transition;
- (void) showTabBarWithTransition:(BOOL) transition;

- (void) registerForRemoteNotifications;

@property (nonatomic, readonly) NSSet *handledURLSchemes;
@property (nonatomic, readonly) NSDate *launchDate;
@property (nonatomic, readonly) UITabBarController *tabBarController;
@property (nonatomic, readonly) UIWindow *mainWindow;
@property (nonatomic, readonly) NSString *deviceToken;
@property (nonatomic, readonly) NSArray *highlightWords;
@property (nonatomic, readonly) UIColor *tintColor;
@property (nonatomic) BOOL showingTabBar;
@end
