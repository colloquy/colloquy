#import "CQColloquyApplication.h"

#import "CQBrowserViewController.h"
#import "CQConnectionsController.h"
#import "CQChatController.h"
#import "NSStringAdditions.h"
#import "RegexKitLite.h"

#if ENABLE(SECRETS)
@interface UIApplication (UIApplicationPrivate)
- (BOOL) launchApplicationWithIdentifier:(NSString *) bundleIdentifier suspended:(BOOL) suspended;
@end
#endif

NSString *CQColloquyApplicationDidRecieveDeviceTokenNotification = @"CQColloquyApplicationDidRecieveDeviceTokenNotification";

@implementation CQColloquyApplication
+ (CQColloquyApplication *) sharedApplication {
	return (CQColloquyApplication *)[UIApplication sharedApplication];
}

- (void) dealloc {
	[_launchDate release];
	[_deviceToken release];

	[super dealloc];
}

#pragma mark -

@synthesize tabBarController, mainWindow;
@synthesize launchDate = _launchDate;
@synthesize deviceToken = _deviceToken;

#pragma mark -

- (NSArray *) highlightWords {
	static NSMutableArray *highlightWords;
	if (!highlightWords) {
		highlightWords = [[NSMutableArray alloc] init];

		NSString *highlightWordsString = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQHighlightWords"];
		if (highlightWordsString.length) {
			[highlightWords addObjectsFromArray:[highlightWordsString componentsMatchedByRegex:@"(?<=\\s|^)[/\"'](.*?)[/\"'](?=\\s|$)" capture:1]];

			highlightWordsString = [highlightWordsString stringByReplacingOccurrencesOfRegex:@"(?<=\\s|^)[/\"'].*?[/\"'](?=\\s|$)" withString:@""];

			[highlightWords addObjectsFromArray:[highlightWordsString componentsSeparatedByString:@" "]];
			[highlightWords removeObject:@""];
		}
	}

	return highlightWords;
}

- (void) performDeferredLaunchWork {
	NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
	NSString *version = [NSString stringWithFormat:@"%@ (%@)", [info objectForKey:@"CFBundleShortVersionString"], [info objectForKey:@"CFBundleVersion"]];
	[[NSUserDefaults standardUserDefaults] setObject:version forKey:@"CQCurrentVersion"];

#ifdef ENABLE_SECRETS
	NSString *preferencesPath = [@"~/../../Library/Preferences/com.apple.Preferences.plist" stringByStandardizingPath];
	NSMutableDictionary *preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:preferencesPath];

	if (preferences && ![[preferences objectForKey:@"KeyboardEmojiEverywhere"] boolValue]) {
		[preferences setValue:[NSNumber numberWithBool:YES] forKey:@"KeyboardEmojiEverywhere"];
		[preferences writeToFile:preferencesPath atomically:YES];
	}

	[preferences release];
#endif
}

#pragma mark -

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

	NSDictionary *pushInfo = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
	NSString *connectionServer = [pushInfo objectForKey:@"s"];
	NSString *connectionIdentifier = [pushInfo objectForKey:@"c"];
	if (connectionServer.length || connectionIdentifier.length) {
		NSString *roomName = [pushInfo objectForKey:@"r"];
		NSString *senderNickname = [pushInfo objectForKey:@"n"];

		MVChatConnection *connection = nil;

		if (connectionIdentifier.length)
			connection = [[CQConnectionsController defaultController] connectionForUniqueIdentifier:connectionIdentifier];
		if (!connection && connectionServer.length)
			connection = [[CQConnectionsController defaultController] connectionForServerAddress:connectionServer];

		if (connection) {
			[connection connect];

			if (roomName.length) {
				[[CQChatController defaultController] showChatControllerWhenAvailableForRoomNamed:roomName andConnection:connection];

				tabBarController.selectedViewController = [CQChatController defaultController];
			} else if (senderNickname.length) {
				[[CQChatController defaultController] showChatControllerForUserNicknamed:senderNickname andConnection:connection];

				tabBarController.selectedViewController = [CQChatController defaultController];
			}
		}
	}

	NSString *style = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQChatTranscriptStyle"];

	if ([style hasSuffix:@"-dark"] || [style isEqualToString:@"notes"])
		[[CQColloquyApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];

	[self performSelector:@selector(performDeferredLaunchWork) withObject:nil afterDelay:1.];

	return YES;
}

- (void) application:(UIApplication *) application didReceiveRemoteNotification:(NSDictionary *) userInfo {
	NSDictionary *apsInfo = [userInfo objectForKey:@"aps"];
	if (!apsInfo.count)
		return;

	self.applicationIconBadgeNumber = [[apsInfo objectForKey:@"badge"] integerValue];
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

	const unsigned *tokenData = deviceToken.bytes;
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

#pragma mark -

- (void) showActionSheet:(UIActionSheet *) sheet {
	UITabBar *tabBar = tabBarController.tabBar;
	if (tabBar) [sheet showFromTabBar:tabBar];
	else [sheet showInView:tabBarController.view];
}

#pragma mark -

- (void) setNetworkActivityIndicatorVisible:(BOOL) visible {
	if (visible) {
		++_networkIndicatorStack;
		super.networkActivityIndicatorVisible = YES;
	} else {
		if (_networkIndicatorStack)
			--_networkIndicatorStack;
		if (!_networkIndicatorStack)
			super.networkActivityIndicatorVisible = NO;
	}
}

#pragma mark -

- (void) launchSettings {
#if ENABLE(SECRETS)
	if (![self respondsToSelector:@selector(launchApplicationWithIdentifier:suspended:)])
		return;
	[self launchApplicationWithIdentifier:@"com.apple.Preferences" suspended:NO];
#endif
}

#pragma mark -

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

#pragma mark -

- (void) tabBarController:(UITabBarController *) currentTabBarController didSelectViewController:(UIViewController *) viewController {
	[[NSUserDefaults standardUserDefaults] setInteger:tabBarController.selectedIndex forKey:@"CQSelectedTabIndex"];
}

#pragma mark -

- (UIColor *) tintColor {
	NSString *style = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQChatTranscriptStyle"];

	if ([style hasSuffix:@"-dark"])
		return [UIColor blackColor];
	if ([style isEqualToString:@"notes"])
		return [UIColor colorWithRed:.224 green:.082 blue:.0 alpha:1];;
	return nil;
}

@end
