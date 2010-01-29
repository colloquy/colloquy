@protocol CQBrowserViewControllerDelegate;

extern NSString *CQColloquyApplicationDidRecieveDeviceTokenNotification;

@interface CQColloquyApplication : UIApplication <UIApplicationDelegate, UITabBarControllerDelegate, UIAlertViewDelegate> {
	@protected
	UIWindow *_mainWindow;
	UIViewController *_mainViewController;
	NSDate *_launchDate;
	NSString *_deviceToken;
	NSUInteger _networkIndicatorStack;
	BOOL _showingTabBar;
}
+ (CQColloquyApplication *) sharedApplication;

- (void) showHelp;
- (void) showWelcome;
- (void) showConnections;
- (void) showColloquies;

- (BOOL) isSpecialApplicationURL:(NSURL *) url;
- (NSString *) applicationNameForURL:(NSURL *) url;

- (BOOL) openURL:(NSURL *) url usingBuiltInBrowser:(BOOL) openWithBrowser;
- (BOOL) openURL:(NSURL *) url usingBuiltInBrowser:(BOOL) openWithBrowser withBrowserDelegate:(id <CQBrowserViewControllerDelegate>) delegate;
- (BOOL) openURL:(NSURL *) url usingBuiltInBrowser:(BOOL) openWithBrowser withBrowserDelegate:(id <CQBrowserViewControllerDelegate>) delegate promptForExternal:(BOOL) prompt;

- (void) showActionSheet:(UIActionSheet *) sheet;
- (void) showActionSheet:(UIActionSheet *) sheet forSender:(id) sender animated:(BOOL) animated;

- (void) hideTabBarWithTransition:(BOOL) transition;
- (void) showTabBarWithTransition:(BOOL) transition;

- (void) registerForRemoteNotifications;

@property (nonatomic, readonly) NSSet *handledURLSchemes;
@property (nonatomic, readonly) NSDate *launchDate;
@property (nonatomic, readonly) NSString *deviceToken;
@property (nonatomic, readonly) NSArray *highlightWords;
@property (nonatomic, readonly) UIColor *tintColor;
@property (nonatomic) BOOL showingTabBar;
@end
