#import "CQColloquyApplication.h"

#import "CQAnalyticsController.h"
#import "CQBrowserViewController.h"
#import "CQChatController.h"
#import "CQConnectionsController.h"
#import "CQWelcomeNavigationController.h"
#import "NSStringAdditions.h"
#import "RegexKitLite.h"

#import "CQAlertView.h"

#if ENABLE(SECRETS)
typedef enum {
    UITabBarTransitionNone,
    UITabBarTransitionSlide
} UITabBarTransition;

@interface UITabBarController (UITabBarControllerPrivate)
- (void) hideBarWithTransition:(UITabBarTransition) transition;
- (void) showBarWithTransition:(UITabBarTransition) transition;
@end
#endif

NSString *CQColloquyApplicationDidRecieveDeviceTokenNotification = @"CQColloquyApplicationDidRecieveDeviceTokenNotification";

#define BrowserAlertTag 1

@implementation CQColloquyApplication
+ (void) updateAnalytics {
	[[CQAnalyticsController defaultController] setObject:[[[NSUserDefaults standardUserDefaults] stringForKey:@"CQChatTranscriptStyle"] lowercaseString] forKey:@"transcript-style"];

	NSString *information = ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQGraphicalEmoticons"] ? @"emoji" : @"text");
	[[CQAnalyticsController defaultController] setObject:information forKey:@"emoticon-style"];

	information = ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"] ? @"disabled" : @"enabled");
	[[CQAnalyticsController defaultController] setObject:information forKey:@"landscape"];

	information = ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableBuiltInBrowser"] ? @"disabled" : @"enabled");
	[[CQAnalyticsController defaultController] setObject:information forKey:@"browser"];

	information = ([[NSUserDefaults standardUserDefaults] stringForKey:@"CQTwitterUsername"].length ? @"yes" : @"no");
	[[CQAnalyticsController defaultController] setObject:information forKey:@"twitter-setup"];

	information = ([[NSUserDefaults standardUserDefaults] stringForKey:@"CQInstapaperUsername"].length ? @"yes" : @"no");
	[[CQAnalyticsController defaultController] setObject:information forKey:@"instapaper-setup"];

	information = [[NSLocale autoupdatingCurrentLocale] localeIdentifier];
	[[CQAnalyticsController defaultController] setObject:information forKey:@"locale"];

	if (_deviceToken.length)
		[[CQAnalyticsController defaultController] setObject:_deviceToken forKey:@"device-push-token"];

	[[CQAnalyticsController defaultController] setObject:[[[NSUserDefaults standardUserDefaults] stringForKey:@"CQChatAutocompleteBehavior"] lowercaseString] forKey:@"autocomplete-behavior"];

	NSInteger showNotices = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatAlwaysShowNotices"];
	information = (!showNotices ? @"auto" : (showNotices == 1 ? @"all" : @"none"));
	[[CQAnalyticsController defaultController] setObject:information forKey:@"notices-behavior"];

	information = ([[[NSUserDefaults standardUserDefaults] stringForKey:@"JVQuitMessage"] hasCaseInsensitiveSubstring:@"Colloquy for iPhone"] ? @"default" : @"custom");
	[[CQAnalyticsController defaultController] setObject:information forKey:@"quit-message"];
}

+ (void) userDefaultsChanged {
	NSString *style = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQChatTranscriptStyle"];
	if ([style hasSuffix:@"-dark"] || [style isEqualToString:@"notes"])
		[self setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];

}

+ (void) initialize {
	static BOOL userDefaultsInitialized;

	if (userDefaultsInitialized)
		return;

	userDefaultsInitialized = YES;

	[[NSNotificationCenter defaultCenter] addObserver:[CQColloquyApplication class] selector:@selector(userDefaultsChanged) name:NSUserDefaultsDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:[CQColloquyApplication class] selector:@selector(updateAnalytics) name:NSUserDefaultsDidChangeNotification object:nil];
}

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
@synthesize showingTabBar = _showingTabBar;

#pragma mark -

- (NSSet *) handledURLSchemes {
	static NSMutableSet *schemes;
	if (!schemes) {
		schemes = [[NSMutableSet alloc] init];

		NSArray *urlTypes = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleURLTypes"];
		for (NSDictionary *type in urlTypes) {
			NSArray *schemesForType = [type objectForKey:@"CFBundleURLSchemes"];
			for (NSString *scheme in schemesForType)
				[schemes addObject:[scheme lowercaseString]];
		}
	}

	return schemes;
}

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
	NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
	NSString *version = [NSString stringWithFormat:@"%@ (%@)", [infoDictionary objectForKey:@"CFBundleShortVersionString"], [infoDictionary objectForKey:@"CFBundleVersion"]];
	[[NSUserDefaults standardUserDefaults] setObject:version forKey:@"CQCurrentVersion"];

	NSString *preferencesPath = [@"~/../../Library/Preferences/com.apple.Preferences.plist" stringByStandardizingPath];
	NSMutableDictionary *preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:preferencesPath];

	if (preferences && ![[preferences objectForKey:@"KeyboardEmojiEverywhere"] boolValue]) {
		[preferences setValue:[NSNumber numberWithBool:YES] forKey:@"KeyboardEmojiEverywhere"];
		[preferences writeToFile:preferencesPath atomically:YES];
	}

	[preferences release];

	NSString *information = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
	[[CQAnalyticsController defaultController] setObject:information forKey:@"application-version"];

	information = [infoDictionary objectForKey:@"CFBundleVersion"];
	[[CQAnalyticsController defaultController] setObject:information forKey:@"application-build-version"];

#if defined(TARGET_IPHONE_SIMULATOR) && TARGET_IPHONE_SIMULATOR
	information = @"simulator";
#else
	if ([infoDictionary objectForKey:@"SignerIdentity"]) {
		information = @"cracked";
	} else {
		NSString *type = [infoDictionary objectForKey:@"CQBuildType"];
		BOOL officialBundleIdentifier = [[infoDictionary objectForKey:@"CFBundleIdentifier"] isEqualToString:@"info.colloquy.mobile"];
		if ([type isEqualToString:@"personal"] || !officialBundleIdentifier)
			information = @"personal";
		else if ([type isEqualToString:@"beta"] && officialBundleIdentifier)
			information = @"beta";
		else if ([type isEqualToString:@"official"] || officialBundleIdentifier)
			information = @"official";
	}
#endif

	[[CQAnalyticsController defaultController] setObject:information forKey:@"install-type"];

	[[CQAnalyticsController defaultController] setObject:[[[NSUserDefaults standardUserDefaults] stringForKey:@"CQChatTranscriptStyle"] lowercaseString] forKey:@"transcript-style"];

	information = ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQGraphicalEmoticons"] ? @"emoji" : @"text");
	[[CQAnalyticsController defaultController] setObject:information forKey:@"emoticon-style"];

	information = ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"] ? @"disabled" : @"enabled");
	[[CQAnalyticsController defaultController] setObject:information forKey:@"landscape"];

	information = ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableBuiltInBrowser"] ? @"disabled" : @"enabled");
	[[CQAnalyticsController defaultController] setObject:information forKey:@"browser"];

	information = ([[NSUserDefaults standardUserDefaults] stringForKey:@"CQTwitterUsername"].length ? @"yes" : @"no");
	[[CQAnalyticsController defaultController] setObject:information forKey:@"twitter-setup"];

	information = ([[NSUserDefaults standardUserDefaults] stringForKey:@"CQInstapaperUsername"].length ? @"yes" : @"no");
	[[CQAnalyticsController defaultController] setObject:information forKey:@"instapaper-setup"];

	information = [[NSLocale autoupdatingCurrentLocale] localeIdentifier];
	[[CQAnalyticsController defaultController] setObject:information forKey:@"locale"];
	if (_deviceToken.length)
		[[CQAnalyticsController defaultController] setObject:_deviceToken forKey:@"device-push-token"];

	[[CQAnalyticsController defaultController] setObject:[[[NSUserDefaults standardUserDefaults] stringForKey:@"CQChatAutocompleteBehavior"] lowercaseString] forKey:@"autocomplete-behavior"];

	NSInteger showNotices = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatAlwaysShowNotices"];
	information = (!showNotices ? @"auto" : (showNotices == 1 ? @"all" : @"none"));
	[[CQAnalyticsController defaultController] setObject:information forKey:@"notices-behavior"];

	information = ([[[NSUserDefaults standardUserDefaults] stringForKey:@"JVQuitMessage"] hasCaseInsensitiveSubstring:@"Colloquy for iPhone"] ? @"default" : @"custom");
	[[CQAnalyticsController defaultController] setObject:information forKey:@"quit-message"];
}

#pragma mark -

- (BOOL) application:(UIApplication *) application didFinishLaunchingWithOptions:(NSDictionary *) launchOptions {
	NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];

	_launchDate = [[NSDate alloc] init];
	_deviceToken = [[[NSUserDefaults standardUserDefaults] stringForKey:@"CQPushDeviceToken"] retain];
	_showingTabBar = YES;

	NSString *style = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQChatTranscriptStyle"];
	if ([style hasSuffix:@"-dark"] || [style isEqualToString:@"notes"])
		[self setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];

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
			[connection connectAppropriately];

			if (roomName.length) {
				[[CQChatController defaultController] showChatControllerWhenAvailableForRoomNamed:roomName andConnection:connection];

				tabBarController.selectedViewController = [CQChatController defaultController];
			} else if (senderNickname.length) {
				[[CQChatController defaultController] showChatControllerForUserNicknamed:senderNickname andConnection:connection];

				tabBarController.selectedViewController = [CQChatController defaultController];
			}
		}
	}

	NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
	BOOL showWelcomeScreen = ![[[NSUserDefaults standardUserDefaults] stringForKey:@"CQLastBuildWelcomeScreenAppeared"] isEqualToString:version];
	if (showWelcomeScreen || (![CQConnectionsController defaultController].connections.count && ![CQConnectionsController defaultController].bouncers.count)) {
		CQWelcomeNavigationController *welcomeController = [[CQWelcomeNavigationController alloc] init];
		[tabBarController presentModalViewController:welcomeController animated:YES];
		[welcomeController release];

		[[NSUserDefaults standardUserDefaults] setObject:version forKey:@"CQLastBuildWelcomeScreenAppeared"];
	}

	[self performSelector:@selector(performDeferredLaunchWork) withObject:nil afterDelay:1.];

	return YES;
}

- (void) application:(UIApplication *) application didReceiveRemoteNotification:(NSDictionary *) userInfo {
	NSDictionary *apsInfo = [userInfo objectForKey:@"aps"];
	if (!apsInfo.count)
		return;

	self.applicationIconBadgeNumber = [[apsInfo objectForKey:@"badge"] integerValue];
}

- (void) application:(UIApplication *) application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *) deviceToken {
	if (!deviceToken.length) {
		[[CQAnalyticsController defaultController] setObject:nil forKey:@"device-push-token"];

		[_deviceToken release];
		_deviceToken = nil;
		return;
	}

	const unsigned *tokenData = deviceToken.bytes;
	NSString *deviceTokenString = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x", ntohl(tokenData[0]), ntohl(tokenData[1]), ntohl(tokenData[2]), ntohl(tokenData[3]), ntohl(tokenData[4]), ntohl(tokenData[5]), ntohl(tokenData[6]), ntohl(tokenData[7])];

	if ([_deviceToken isEqualToString:deviceTokenString] || !deviceTokenString)
		return;

	[[CQAnalyticsController defaultController] setObject:deviceTokenString forKey:@"device-push-token"];
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

- (void) applicationWillTerminate:(UIApplication *) application {
	NSTimeInterval runTime = ABS([_launchDate timeIntervalSinceNow]);
	[[CQAnalyticsController defaultController] setObject:[NSNumber numberWithDouble:runTime] forKey:@"run-time"];
}

#pragma mark -

- (void) showActionSheet:(UIActionSheet *) sheet {
	UITabBar *tabBar = tabBarController.tabBar;
	if (tabBar && !tabBarController.modalViewController)
		[sheet showFromTabBar:tabBar];
	else [sheet showInView:mainWindow];
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

- (void) showHelp {
	CQWelcomeNavigationController *welcomeController = [[CQWelcomeNavigationController alloc] init];
	welcomeController.shouldShowOnlyHelpTopics = YES;

	[tabBarController presentModalViewController:welcomeController animated:YES];

	[welcomeController release];
}

- (BOOL) isSpecialApplicationURL:(NSURL *) url {
#if !TARGET_IPHONE_SIMULATOR
	return (url && ([url.host hasCaseInsensitiveSubstring:@"maps.google."] || [url.host hasCaseInsensitiveSubstring:@"youtube."] || [url.host hasCaseInsensitiveSubstring:@"phobos.apple."]));
#else
	return NO;
#endif
}

- (NSString *) applicationNameForURL:(NSURL *) url {
	if (!url)
		return nil;
#if !TARGET_IPHONE_SIMULATOR
	if ([url.host hasCaseInsensitiveSubstring:@"maps.google."])
		return NSLocalizedString(@"Maps", @"Maps application name");
	if ([url.host hasCaseInsensitiveSubstring:@"youtube."])
		return NSLocalizedString(@"YouTube", @"YouTube application name");
	if ([url.host hasCaseInsensitiveSubstring:@"phobos.apple."])
		return NSLocalizedString(@"iTunes", @"iTunes application name");
	if ([url.scheme isCaseInsensitiveEqualToString:@"mailto"])
		return NSLocalizedString(@"Mail", @"Mail application name");
#endif
	if ([url.scheme isCaseInsensitiveEqualToString:@"http"] || [url.scheme isCaseInsensitiveEqualToString:@"https"])
		return NSLocalizedString(@"Safari", @"Safari application name");
	return nil;
}

- (BOOL) openURL:(NSURL *) url {
	BOOL openWithBrowser = ![[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableBuiltInBrowser"];
	return [self openURL:url usingBuiltInBrowser:openWithBrowser withBrowserDelegate:nil promptForExternal:openWithBrowser];
}

- (BOOL) openURL:(NSURL *) url usingBuiltInBrowser:(BOOL) openWithBrowser {
	return [self openURL:url usingBuiltInBrowser:openWithBrowser withBrowserDelegate:nil promptForExternal:openWithBrowser];
}

- (BOOL) openURL:(NSURL *) url usingBuiltInBrowser:(BOOL) openWithBrowser withBrowserDelegate:(id <CQBrowserViewControllerDelegate>) delegate {
	return [self openURL:url usingBuiltInBrowser:openWithBrowser withBrowserDelegate:delegate promptForExternal:openWithBrowser];
}

- (BOOL) openURL:(NSURL *) url usingBuiltInBrowser:(BOOL) openWithBrowser withBrowserDelegate:(id <CQBrowserViewControllerDelegate>) delegate promptForExternal:(BOOL) prompt {
	if ([[CQConnectionsController defaultController] handleOpenURL:url])
		return YES;

	if (![self canOpenURL:url])
		return NO;

	BOOL loadLastURL = [url.absoluteString isCaseInsensitiveEqualToString:@"about:last"];
	if (loadLastURL)
		openWithBrowser = YES;

	if (!loadLastURL && openWithBrowser && url && ![url.scheme isCaseInsensitiveEqualToString:@"http"] && ![url.scheme isCaseInsensitiveEqualToString:@"https"])
		openWithBrowser = NO;

	if (!loadLastURL && openWithBrowser && [self isSpecialApplicationURL:url])
		openWithBrowser = NO;

	if (!openWithBrowser) {
		if (!prompt)
			return [super openURL:url];

		CQAlertView *alert = [[CQAlertView alloc] init];

		alert.tag = BrowserAlertTag;

		NSString *applicationName = [self applicationNameForURL:url];
		if (applicationName)
			alert.title = [NSString stringWithFormat:NSLocalizedString(@"Open Link in %@?", @"Open link in app alert title"), applicationName];
		else alert.title = NSLocalizedString(@"Open Link?", @"Open link alert title");

		alert.message = NSLocalizedString(@"Opening this link will close Colloquy.", @"Opening link alert message");
		alert.userInfo = url;
		alert.delegate = self;

		alert.cancelButtonIndex = [alert addButtonWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title")];

		[alert addButtonWithTitle:NSLocalizedString(@"Open", @"Open button title")];

		[alert show];
		[alert release];

		return YES;
	}

	CQBrowserViewController *browserController = [[CQBrowserViewController alloc] init];

	if (loadLastURL) [browserController loadLastURL];
	else if (url) [browserController loadURL:url];

	browserController.delegate = delegate;
	[tabBarController presentModalViewController:browserController animated:YES];

	[browserController release];

	return YES;
}

#pragma mark -

- (void) alertView:(UIAlertView *) alertView clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (alertView.tag != BrowserAlertTag || alertView.cancelButtonIndex == buttonIndex)
		return;
	[super openURL:((CQAlertView *)alertView).userInfo];
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
		return [UIColor colorWithRed:0.224 green:0.082 blue:0. alpha:1.];
	return nil;
}

#pragma mark -

- (void) hideTabBarWithTransition:(BOOL) transition {
#ifdef ENABLE_SECRETS
	if (!_showingTabBar)
		return;

	if ([tabBarController respondsToSelector:@selector(hideBarWithTransition:)]) 
		[tabBarController hideBarWithTransition:(transition ? UITabBarTransitionSlide : UITabBarTransitionNone)];

	_showingTabBar = NO;	#endif}

- (void) showTabBarWithTransition:(BOOL) transition {
#ifdef ENABLE_SECRETS
	if (_showingTabBar)
		return;

	if ([tabBarController respondsToSelector:@selector(showBarWithTransition:)])
		[tabBarController showBarWithTransition:(transition ? UITabBarTransitionSlide : UITabBarTransitionNone)];

	_showingTabBar = YES;
#endif}

#pragma mark -

- (void) registerForRemoteNotifications {
#if !TARGET_IPHONE_SIMULATOR
	static BOOL registeredForPush;
	if (!registeredForPush) {
		[self registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
		registeredForPush = YES;
	}
#endif
}
@end
