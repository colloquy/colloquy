@protocol CQBrowserViewControllerDelegate;

extern NSString *CQColloquyApplicationDidRecieveDeviceTokenNotification;

@interface CQColloquyApplication : UIApplication <UIApplicationDelegate, UITabBarDelegate> {
	@protected
	IBOutlet UIWindow *mainWindow;
	IBOutlet UITabBarController	*tabBarController;
	NSDate *_launchDate;
	NSString *_deviceToken;
}
+ (CQColloquyApplication *) sharedApplication;

- (BOOL) isSpecialApplicationURL:(NSURL *) url;

- (BOOL) openURL:(NSURL *) url usingBuiltInBrowser:(BOOL) openWithBrowser;
- (BOOL) openURL:(NSURL *) url usingBuiltInBrowser:(BOOL) openWithBrowser withBrowserDelegate:(id <CQBrowserViewControllerDelegate>) delegate;

- (void) showActionSheet:(UIActionSheet *) sheet;

@property (nonatomic, readonly) NSDate *launchDate;
@property (nonatomic, readonly) UITabBarController *tabBarController;
@property (nonatomic, readonly) UIWindow *mainWindow;
@property (nonatomic, readonly) NSString *deviceToken;
@end
