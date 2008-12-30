#import "CQColloquyApplication.h"

#import "CQBrowserViewController.h"
#import "CQConnectionsController.h"
#import "CQChatController.h"
#import "NSStringAdditions.h"

@implementation CQColloquyApplication
+ (CQColloquyApplication *) sharedApplication {
	return (CQColloquyApplication *)[UIApplication sharedApplication];
}

@synthesize tabBarController, mainWindow;

- (void) dealloc {
	[tabBarController release];
	[mainWindow release];
	[super dealloc];
}

- (void) applicationDidFinishLaunching:(UIApplication *) application {
	NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];

	NSArray *viewControllers = [[NSArray alloc] initWithObjects:[CQConnectionsController defaultController], [CQChatController defaultController], nil];
	tabBarController.viewControllers = viewControllers;
	[viewControllers release];

	tabBarController.selectedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"CQSelectedTabIndex"];

	[mainWindow addSubview:tabBarController.view];
	[mainWindow makeKeyAndVisible];
}

- (BOOL) application:(UIApplication *) application handleOpenURL:(NSURL *) url {
	return [[CQConnectionsController defaultController] handleOpenURL:url];
}

- (BOOL) openURL:(NSURL *) url usingBuiltInBrowser:(BOOL) openWithBrowser {
	if (!url && !openWithBrowser)
		return NO;

	if (openWithBrowser && url && ![url.scheme isEqualToString:@"http"] && ![url.scheme isEqualToString:@"https"])
		openWithBrowser = NO;

	if (openWithBrowser && url && [url.host hasCaseInsensitiveSubstring:@"maps.google."])
		openWithBrowser = NO;

	if (openWithBrowser && url && [url.host hasCaseInsensitiveSubstring:@"youtube."])
		openWithBrowser = NO;

	if (!openWithBrowser)
		return [self openURL:url];

	CQBrowserViewController *browserController = [[CQBrowserViewController alloc] init];
	if (url) [browserController loadURL:url];

	[tabBarController presentModalViewController:browserController animated:YES];

	[browserController release];

	return YES;
}

- (void) tabBarController:(UITabBarController *) currentTabBarController didSelectViewController:(UIViewController *) viewController {
	[[NSUserDefaults standardUserDefaults] setInteger:tabBarController.selectedIndex forKey:@"CQSelectedTabIndex"];
}
@end
