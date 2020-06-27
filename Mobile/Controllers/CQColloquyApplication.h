@protocol CQBrowserViewControllerDelegate;

NS_ASSUME_NONNULL_BEGIN

extern NSString *CQColloquyApplicationDidRecieveDeviceTokenNotification;

typedef NS_OPTIONS(NSInteger, CQAppIconOptions) {
	CQAppIconOptionNone = 0,
	CQAppIconOptionConnect = 1 << 0,
	CQAppIconOptionNewChat = 1 << 2,
	CQAppIconOptionNewPrivateChat = 1 << 3,
	CQAppIconOptionNewConnection = 1 << 4
};

@interface CQColloquyApplication : UIApplication
+ (CQColloquyApplication *) sharedApplication;

- (void) showHelp:(__nullable id) sender;
- (void) showWelcome:(__nullable id) sender;
- (void) showConnections:(__nullable id) sender;

- (void) dismissPopoversAnimated:(BOOL) animated;

- (BOOL) isSpecialApplicationURL:(NSURL *) url;
- (NSString *) applicationNameForURL:(NSURL *) url;

- (void) showActionSheet:(CQActionSheet *) sheet;
- (void) showActionSheet:(CQActionSheet *) sheet fromPoint:(CGPoint) point;
- (void) showActionSheet:(CQActionSheet *) sheet forSender:(__nullable id) sender animated:(BOOL) animated;

@property (nonatomic, readonly) UIViewController *mainViewController;
@property (nonatomic, readonly) UIViewController *modalViewController;

- (void) presentModalViewController:(UIViewController *) modalViewController animated:(BOOL) animated;
- (void) presentModalViewController:(UIViewController *) modalViewController animated:(BOOL) animated singly:(BOOL) singly;
- (void) dismissModalViewControllerAnimated:(BOOL) animated;

#if !SYSTEM(TV)
- (void) registerForPushNotifications;
#endif

@property (nonatomic, readonly) NSDate *launchDate;
@property (nonatomic, strong) NSDate *resumeDate;

#if !SYSTEM(TV)
- (void) updateAppShortcuts;
@property (nonatomic) CQAppIconOptions appIconOptions;
#endif

- (void) submitRunTime;

@property (nonatomic, readonly) NSSet *handledURLSchemes;
@property (nonatomic, readonly) NSString *deviceToken;
@property (nonatomic, readonly) NSArray <NSString *> *highlightWords;
@property (nonatomic, readonly, nullable) UIColor *tintColor;

@property (readonly, strong) UISplitViewController *splitViewController;
@end

NS_ASSUME_NONNULL_END
