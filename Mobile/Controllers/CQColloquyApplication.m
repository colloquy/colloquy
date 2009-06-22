#import "CQColloquyApplication.h"

#import "CQBrowserViewController.h"
#import "CQConnectionsController.h"
#import "CQChatController.h"
#import "NSStringAdditions.h"

#if defined(ENABLE_SECRETS) && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_0
@interface UITabBarController (UITabBarControllerPrivate)
@property (nonatomic, readonly) UITabBar *tabBar;
@end
#endif

#pragma mark -

#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_0
typedef enum {
	UIRemoteNotificationTypeNone = 0,
	UIRemoteNotificationTypeBadge = 1 << 0,
	UIRemoteNotificationTypeSound = 1 << 1,
	UIRemoteNotificationTypeAlert = 1 << 2
} UIRemoteNotificationType;

@interface UIApplication (UIApplicationNew)
- (void) registerForRemoteNotificationTypes:(UIRemoteNotificationType) types;
@end
#endif

#pragma mark -

NSString *CQColloquyApplicationDidRecieveDeviceTokenNotification = @"CQColloquyApplicationDidRecieveDeviceTokenNotification";

@implementation CQColloquyApplication
+ (CQColloquyApplication *) sharedApplication {
	return (CQColloquyApplication *)[UIApplication sharedApplication];
}

@synthesize tabBarController, mainWindow;

- (void) dealloc {
	[_launchDate release];
	[_deviceToken release];

	[super dealloc];
}

@synthesize launchDate = _launchDate;
@synthesize deviceToken = _deviceToken;

- (BOOL) application:(UIApplication *) application didFinishLaunchingWithOptions:(NSDictionary *) launchOptions {
	NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];

	_launchDate = [[NSDate alloc] init];

	_deviceToken = [[[NSUserDefaults standardUserDefaults] stringForKey:@"CQPushDeviceToken"] retain];

#if !TARGET_IPHONE_SIMULATOR
	if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerForRemoteNotificationTypes:)])
		[[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
#endif

	NSArray *viewControllers = [[NSArray alloc] initWithObjects:[CQConnectionsController defaultController], [CQChatController defaultController], nil];
	tabBarController.viewControllers = viewControllers;
	[viewControllers release];

	tabBarController.selectedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"CQSelectedTabIndex"];

	[mainWindow addSubview:tabBarController.view];
	[mainWindow makeKeyAndVisible];

	NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
	NSString *version = [NSString stringWithFormat:@"%@ (%@)", [info objectForKey:@"CFBundleShortVersionString"], [info objectForKey:@"CFBundleVersion"]];
	[[NSUserDefaults standardUserDefaults] setObject:version forKey:@"CQCurrentVersion"];

	return YES;
}

#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_0
- (void) applicationDidFinishLaunching:(UIApplication *) application {
	[self application:self didFinishLaunchingWithOptions:nil];
}
#endif

- (void) application:(UIApplication *) application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *) deviceToken {
	if (!deviceToken.length) {
		[_deviceToken release];
		_deviceToken = nil;
		return;
	}

	const unsigned int *tokenData = deviceToken.bytes;
	NSString *deviceTokenString = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x", ntohl(tokenData[0]), ntohl(tokenData[1]), ntohl(tokenData[2]), ntohl(tokenData[3]), ntohl(tokenData[4]), ntohl(tokenData[5]), ntohl(tokenData[6]), ntohl(tokenData[7])];

	if ([_deviceToken isEqualToString:deviceTokenString] || !deviceTokenString)
		return;

	[[NSUserDefaults standardUserDefaults] setObject:deviceTokenString forKey:@"CQPushDeviceToken"];

	id old = _deviceToken;
	_deviceToken = [deviceTokenString retain];
	[old release];

	[[NSNotificationCenter defaultCenter] postNotificationName:CQColloquyApplicationDidRecieveDeviceTokenNotification object:self userInfo:[NSDictionary dictionaryWithObject:deviceTokenString forKey:@"deviceToken"]];
}

- (void) application:(UIApplication *) application didFailToRegisterForRemoteNotificationsWithError:(NSError *) error {
	NSLog(@"Error during remote notification registration. Error: %@", error);
}

- (BOOL) application:(UIApplication *) application handleOpenURL:(NSURL *) url {
	return [[CQConnectionsController defaultController] handleOpenURL:url];
}

- (void) showActionSheet:(UIActionSheet *) sheet {
#if defined(ENABLE_SECRETS) && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_0
	UITabBar *tabBar = nil;
	if ([tabBarController respondsToSelector:@selector(tabBar)])
		tabBar = tabBarController.tabBar;
#elif __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_3_0
	UITabBar *tabBar = tabBarController.tabBar;
#endif

	if (tabBar) [sheet showFromTabBar:tabBar];
	else [sheet showInView:tabBarController.view];
}

- (BOOL) isSpecialApplicationURL:(NSURL *) url {
	return (url && ([url.host hasCaseInsensitiveSubstring:@"maps.google."] || [url.host hasCaseInsensitiveSubstring:@"youtube."] || [url.host hasCaseInsensitiveSubstring:@"phobos.apple."]));
}

- (BOOL) openURL:(NSURL *) url {
	if ([[CQConnectionsController defaultController] handleOpenURL:url])
		return YES;
	return [super openURL:url];
}

- (BOOL) openURL:(NSURL *) url usingBuiltInBrowser:(BOOL) openWithBrowser {
	return [self openURL:url usingBuiltInBrowser:openWithBrowser withBrowserDelegate:nil];
}

- (BOOL) openURL:(NSURL *) url usingBuiltInBrowser:(BOOL) openWithBrowser withBrowserDelegate:(id <CQBrowserViewControllerDelegate>) delegate {
	if (!url && !openWithBrowser)
		return NO;

	BOOL loadLastURL = [url.absoluteString isCaseInsensitiveEqualToString:@"about:last"];
	if (loadLastURL)
		openWithBrowser = YES;

	if (!loadLastURL && openWithBrowser && url && ![url.scheme isCaseInsensitiveEqualToString:@"http"] && ![url.scheme isCaseInsensitiveEqualToString:@"https"])
		openWithBrowser = NO;

	if (!loadLastURL && openWithBrowser && [self isSpecialApplicationURL:url])
		openWithBrowser = NO;

	if (!openWithBrowser)
		return [self openURL:url];

	CQBrowserViewController *browserController = [[CQBrowserViewController alloc] init];

	if (loadLastURL) [browserController loadLastURL];
	else if (url) [browserController loadURL:url];

	browserController.delegate = delegate;
	[tabBarController presentModalViewController:browserController animated:YES];

	[browserController release];

	return YES;
}

- (void) tabBarController:(UITabBarController *) currentTabBarController didSelectViewController:(UIViewController *) viewController {
	[[NSUserDefaults standardUserDefaults] setInteger:tabBarController.selectedIndex forKey:@"CQSelectedTabIndex"];
}
@end
