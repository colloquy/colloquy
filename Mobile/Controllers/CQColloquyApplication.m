#import "CQColloquyApplication.h"

#import "CQBrowserViewController.h"
#import "CQConnectionsController.h"
#import "CQChatController.h"
#import "NSStringAdditions.h"

#ifdef ENABLE_SECRETS
@interface UITabBarController (UITabBarControllerPrivate)
@property (nonatomic, readonly) UITabBar *tabBar;
@end
#endif

#pragma mark -

@implementation CQColloquyApplication
+ (CQColloquyApplication *) sharedApplication {
	return (CQColloquyApplication *)[UIApplication sharedApplication];
}

@synthesize tabBarController, mainWindow;

- (void) dealloc {
	[_launchDate release];

	[super dealloc];
}

@synthesize launchDate = _launchDate;

- (void) applicationDidFinishLaunching:(UIApplication *) application {
	NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];

	_launchDate = [[NSDate alloc] init];

	NSArray *viewControllers = [[NSArray alloc] initWithObjects:[CQConnectionsController defaultController], [CQChatController defaultController], nil];
	tabBarController.viewControllers = viewControllers;
	[viewControllers release];

	tabBarController.selectedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"CQSelectedTabIndex"];

	[mainWindow addSubview:tabBarController.view];
	[mainWindow makeKeyAndVisible];

	NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
	NSString *version = [NSString stringWithFormat:@"%@ (%@)", [info objectForKey:@"CFBundleShortVersionString"], [info objectForKey:@"CFBundleVersion"]];
	[[NSUserDefaults standardUserDefaults] setObject:version forKey:@"CQCurrentVersion"];
}

- (BOOL) application:(UIApplication *) application handleOpenURL:(NSURL *) url {
	return [[CQConnectionsController defaultController] handleOpenURL:url];
}

- (void) showActionSheet:(UIActionSheet *) sheet {
	UITabBar *tabBar = nil;
#ifdef ENABLE_SECRETS
	if ([tabBarController respondsToSelector:@selector(tabBar)])
		tabBar = tabBarController.tabBar;
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

	if (openWithBrowser && url && ![url.scheme isCaseInsensitiveEqualToString:@"http"] && ![url.scheme isCaseInsensitiveEqualToString:@"https"])
		openWithBrowser = NO;

	if (openWithBrowser && [self isSpecialApplicationURL:url])
		openWithBrowser = NO;

	if (!openWithBrowser)
		return [self openURL:url];

	CQBrowserViewController *browserController = [[CQBrowserViewController alloc] init];
	if (url) [browserController loadURL:url];

	browserController.delegate = delegate;
	[tabBarController presentModalViewController:browserController animated:YES];

	[browserController release];

	return YES;
}

- (void) tabBarController:(UITabBarController *) currentTabBarController didSelectViewController:(UIViewController *) viewController {
	[[NSUserDefaults standardUserDefaults] setInteger:tabBarController.selectedIndex forKey:@"CQSelectedTabIndex"];
}
@end
