#import "CQColloquyApplication.h"

#import "CQAlertView.h"
#import "CQAnalyticsController.h"
#import "CQBrowserViewController.h"
#import "CQChatController.h"
#import "CQChatCreationViewController.h"
#import "CQChatNavigationController.h"
#import "CQChatPresentationController.h"
#import "CQConnectionsController.h"
#import "CQConnectionsNavigationController.h"
#import "CQWelcomeController.h"
#import "RegexKitLite.h"

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
+ (CQColloquyApplication *) sharedApplication {
	return (CQColloquyApplication *)[UIApplication sharedApplication];
}

- (id) init {
	if (!(self = [super init]))
		return nil;

	_launchDate = [[NSDate alloc] init];
	_resumeDate = [_launchDate copy];

	return self;
}

- (void) dealloc {
	[_mainWindow release];
	[_mainViewController release];
	[_colloquiesBarButtonItem release];
	[_colloquiesPopoverController release];
	[_connectionsBarButtonItem release];
	[_connectionsPopoverController release];
	[_launchDate release];
	[_resumeDate release];
	[_deviceToken release];
	[_visibleActionSheet release];

	[super dealloc];
}

#pragma mark -

@synthesize launchDate = _launchDate;
@synthesize resumeDate = _resumeDate;
@synthesize deviceToken = _deviceToken;

#pragma mark -

- (UITabBarController *) tabBarController {
	if ([_mainViewController isKindOfClass:[UITabBarController class]])
		return (UITabBarController *)_mainViewController;
	return nil;
}

- (UISplitViewController *) splitViewController {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_3_2
	if ([_mainViewController isKindOfClass:[UISplitViewController class]])
		return (UISplitViewController *)_mainViewController;
#endif
	return nil;
}

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

			highlightWordsString = [highlightWordsString stringByReplacingOccurrencesOfRegex:@"(?<=\\s|^)[/\"'](.*?)[/\"'](?=\\s|$)" withString:@""];

			[highlightWords addObjectsFromArray:[highlightWordsString componentsSeparatedByString:@" "]];
			[highlightWords removeObject:@""];
		}
	}

	return highlightWords;
}

- (void) updateAnalytics {
	CQAnalyticsController *analyticsController = [CQAnalyticsController defaultController];

	[analyticsController setObject:[[[NSUserDefaults standardUserDefaults] stringForKey:@"CQChatTranscriptStyle"] lowercaseString] forKey:@"transcript-style"];

	NSString *information = ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQGraphicalEmoticons"] ? @"emoji" : @"text");
	[analyticsController setObject:information forKey:@"emoticon-style"];

	information = ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableLandscape"] ? @"0" : @"1");
	[analyticsController setObject:information forKey:@"landscape"];

	information = ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableBuiltInBrowser"] ? @"0" : @"1");
	[analyticsController setObject:information forKey:@"browser"];

	information = ([[NSUserDefaults standardUserDefaults] stringForKey:@"CQInstapaperUsername"].length ? @"1" : @"0");
	[analyticsController setObject:information forKey:@"instapaper-setup"];

	information = [[NSLocale autoupdatingCurrentLocale] localeIdentifier];
	[analyticsController setObject:information forKey:@"locale"];

	[analyticsController setObject:[[[NSUserDefaults standardUserDefaults] stringForKey:@"CQChatAutocompleteBehavior"] lowercaseString] forKey:@"autocomplete-behavior"];

	[analyticsController setObject:[[NSUserDefaults standardUserDefaults] objectForKey:@"CQMultitaskingTimeout"] forKey:@"multitasking-timeout"];

	NSInteger showNotices = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatAlwaysShowNotices"];
	information = (!showNotices ? @"auto" : (showNotices == 1 ? @"all" : @"none"));
	[analyticsController setObject:information forKey:@"notices-behavior"];

	information = ([[[NSUserDefaults standardUserDefaults] stringForKey:@"JVQuitMessage"] hasCaseInsensitiveSubstring:@"Colloquy for"] ? @"default" : @"custom");
	[analyticsController setObject:information forKey:@"quit-message"];
}

- (void) setDefaultMessageStringForKey:(NSString *) key {
	NSString *message = [[NSUserDefaults standardUserDefaults] stringForKey:key];
	if ([message hasCaseInsensitiveSubstring:@"Colloquy for iPhone"]) {
		message = [NSString stringWithFormat:NSLocalizedString(@"Colloquy for %@ - http://colloquy.mobi", @"Status message, with the device name inserted"), [UIDevice currentDevice].localizedModel];
		[[NSUserDefaults standardUserDefaults] setObject:message forKey:key];
	}
}

- (void) userDefaultsChanged {
	if (![NSThread isMainThread])
		return;

	[self updateAnalytics];

	NSString *style = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQChatTranscriptStyle"];
	if ([style hasSuffix:@"-dark"] || [style isEqualToString:@"notes"])
		[[CQColloquyApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	else [[CQColloquyApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
}

- (void) performDeferredLaunchWork {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_4_0
	if ([[UIDevice currentDevice] isSystemFour] && [UIDevice currentDevice].multitaskingSupported && ![[NSUserDefaults standardUserDefaults] objectForKey:@"CQDisabledBuiltInBrowserForMultitasking"]) {
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"CQDisableBuiltInBrowser"];
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"CQDisabledBuiltInBrowserForMultitasking"];
	}
#endif

	NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
	NSString *version = [infoDictionary objectForKey:@"CFBundleShortVersionString"];

	if (![[[NSUserDefaults standardUserDefaults] stringForKey:@"CQLastVersionUsed"] isEqualToString:version]) {
		NSString *displayVersion = [NSString stringWithFormat:@"%@ (%@)", version, [infoDictionary objectForKey:@"CFBundleVersion"]];
		[[NSUserDefaults standardUserDefaults] setObject:displayVersion forKey:@"CQCurrentVersion"];

		NSString *preferencesPath = [@"~/../../Library/Preferences/com.apple.Preferences.plist" stringByStandardizingPath];
		NSMutableDictionary *preferences = [[NSMutableDictionary alloc] initWithContentsOfFile:preferencesPath];

		if (preferences && ![[preferences objectForKey:@"KeyboardEmojiEverywhere"] boolValue]) {
			[preferences setValue:[NSNumber numberWithBool:YES] forKey:@"KeyboardEmojiEverywhere"];
			[preferences writeToFile:preferencesPath atomically:YES];
		}

		[preferences release];

		if (![[NSUserDefaults standardUserDefaults] boolForKey:@"JVSetUpDefaultQuitMessage"]) {
			[self setDefaultMessageStringForKey:@"JVQuitMessage"];
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"JVSetUpDefaultQuitMessage"];
		}

		if (![[NSUserDefaults standardUserDefaults] boolForKey:@"JVSetUpDefaultAwayMessage"]) {
			[self setDefaultMessageStringForKey:@"CQAwayStatus"];
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"JVSetUpDefaultAwayMessage"];
		}

		if (![CQConnectionsController defaultController].connections.count && ![CQConnectionsController defaultController].bouncers.count)
			[self showWelcome:nil];

		[[NSUserDefaults standardUserDefaults] setObject:version forKey:@"CQLastVersionUsed"];
	}

	CQAnalyticsController *analyticsController = [CQAnalyticsController defaultController];

	NSString *information = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
	[analyticsController setObject:information forKey:@"application-version"];

	information = [infoDictionary objectForKey:@"CFBundleVersion"];
	[analyticsController setObject:information forKey:@"application-build-version"];

#if TARGET_IPHONE_SIMULATOR
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

	[analyticsController setObject:information forKey:@"install-type"];

	information = [[NSLocale autoupdatingCurrentLocale] localeIdentifier];
	[analyticsController setObject:information forKey:@"locale"];

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_4_0
	[analyticsController setObject:([[UIDevice currentDevice] isSystemFour] && [UIDevice currentDevice].multitaskingSupported ? @"1" : @"0") forKey:@"multitasking-supported"];
	[analyticsController setObject:([[UIDevice currentDevice] isSystemFour] ? [NSNumber numberWithDouble:[UIScreen mainScreen].scale] : [NSNumber numberWithUnsignedInteger:1]) forKey:@"screen-scale-factor"];
#endif

	if (_deviceToken.length)
		[analyticsController setObject:_deviceToken forKey:@"device-push-token"];

	[self updateAnalytics];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDefaultsChanged) name:NSUserDefaultsDidChangeNotification object:nil];
}

- (void) handleNotificationWithUserInfo:(NSDictionary *) userInfo {
	if (!userInfo.count)
		return;

	NSString *connectionServer = [userInfo objectForKey:@"s"];
	NSString *connectionIdentifier = [userInfo objectForKey:@"c"];
	if (connectionServer.length || connectionIdentifier.length) {
		NSString *roomName = [userInfo objectForKey:@"r"];
		NSString *senderNickname = [userInfo objectForKey:@"n"];
		NSString *action = [userInfo objectForKey:@"a"];

		MVChatConnection *connection = nil;

		if (connectionIdentifier.length)
			connection = [[CQConnectionsController defaultController] connectionForUniqueIdentifier:connectionIdentifier];
		if (!connection && connectionServer.length)
			connection = [[CQConnectionsController defaultController] connectionForServerAddress:connectionServer];

		if (connection) {
			[connection connectAppropriately];

			BOOL animationEnabled = [UIView areAnimationsEnabled];
			[UIView setAnimationsEnabled:NO];

			if (![[UIDevice currentDevice] isPadModel])
				self.tabBarController.selectedViewController = [CQChatController defaultController].chatNavigationController;;

			if (roomName.length) {
				if ([action isEqualToString:@"j"])
					[connection joinChatRoomNamed:roomName];
				[[CQChatController defaultController] showChatControllerWhenAvailableForRoomNamed:roomName andConnection:connection];
			} else if (senderNickname.length) {
				[[CQChatController defaultController] showChatControllerForUserNicknamed:senderNickname andConnection:connection];
			}

			[UIView setAnimationsEnabled:animationEnabled];
		}
	}
}

#pragma mark -

- (BOOL) application:(UIApplication *) application didFinishLaunchingWithOptions:(NSDictionary *) launchOptions {
	NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];

	_deviceToken = [[[NSUserDefaults standardUserDefaults] stringForKey:@"CQPushDeviceToken"] retain];
	_showingTabBar = YES;

	[self userDefaultsChanged];

	[CQConnectionsController defaultController];
	[CQChatController defaultController];

	_mainWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

	if ([[UIDevice currentDevice] isPadModel]) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_3_2
		UISplitViewController *splitViewController = [[UISplitViewController alloc] init];
		splitViewController.delegate = self;

		_connectionsBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Connections", @"Connections button title") style:UIBarButtonItemStyleBordered target:self action:@selector(toggleConnections:)];

		CQChatPresentationController *presentationController = [CQChatController defaultController].chatPresentationController;
		[presentationController setStandardToolbarItems:[NSArray arrayWithObject:_connectionsBarButtonItem] animated:NO];

		NSArray *viewControllers = [[NSArray alloc] initWithObjects:[CQChatController defaultController].chatNavigationController, presentationController, nil];
		splitViewController.viewControllers = viewControllers;
		[viewControllers release];

		_mainViewController = splitViewController;
#endif
	} else {
		UITabBarController *tabBarController = [[UITabBarController alloc] initWithNibName:nil bundle:nil];
		tabBarController.delegate = self;

		NSArray *viewControllers = [[NSArray alloc] initWithObjects:[CQConnectionsController defaultController].connectionsNavigationController, [CQChatController defaultController].chatNavigationController, nil];
		tabBarController.viewControllers = viewControllers;
		[viewControllers release];

		tabBarController.selectedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"CQSelectedTabIndex"];

		_mainViewController = tabBarController;
	}

	[_mainWindow addSubview:_mainViewController.view];
	[_mainWindow makeKeyAndVisible];

	[self handleNotificationWithUserInfo:[launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey]];

	[self performSelector:@selector(performDeferredLaunchWork) withObject:nil afterDelay:1.];

	return YES;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_4_0
- (void) applicationWillEnterForeground:(UIApplication *) application {
	[self cancelAllLocalNotifications];
}

- (void) application:(UIApplication *) application didReceiveLocalNotification:(UILocalNotification *) notification {
	[self handleNotificationWithUserInfo:notification.userInfo];
}
#endif

- (void) application:(UIApplication *) application didReceiveRemoteNotification:(NSDictionary *) userInfo {
	NSDictionary *apsInfo = [userInfo objectForKey:@"aps"];
	if (!apsInfo.count)
		return;

	if ([self areNotificationBadgesAllowed])
		self.applicationIconBadgeNumber = [[apsInfo objectForKey:@"badge"] integerValue];
}

- (void) application:(UIApplication *) application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *) deviceToken {
	if (!deviceToken.length) {
		[[CQAnalyticsController defaultController] setObject:nil forKey:@"device-push-token"];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"CQPushDeviceToken"];

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
	if ([[UIDevice currentDevice] isSystemFour])
		[UIApplication sharedApplication].applicationIconBadgeNumber = 0;

	[self submitRunTime];
}

#pragma mark -

- (void) splitViewController:(UISplitViewController *) splitViewController willHideViewController:(UIViewController *) viewController withBarButtonItem:(UIBarButtonItem *) barButtonItem forPopoverController:(UIPopoverController *) popoverController {
	CQChatPresentationController *chatPresentationController = [CQChatController defaultController].chatPresentationController;
	NSMutableArray *items = [chatPresentationController.standardToolbarItems mutableCopy];

	if ([items objectAtIndex:0] == barButtonItem) {
		[items release];

		return;
	}

	if (viewController == [CQChatController defaultController].chatNavigationController) {
		id old = _colloquiesPopoverController;
		_colloquiesPopoverController = [popoverController retain];
		[old release];

		old = _colloquiesBarButtonItem;
		_colloquiesBarButtonItem = [barButtonItem retain];
		[old release];

		[barButtonItem setAction:@selector(toggleColloquies:)];
		[barButtonItem setTarget:self];
	}

	[items insertObject:barButtonItem atIndex:0];

	[chatPresentationController setStandardToolbarItems:items animated:NO];

	[items release];
}

- (void) splitViewController:(UISplitViewController *) splitViewController willShowViewController:(UIViewController *) viewController invalidatingBarButtonItem:(UIBarButtonItem *) barButtonItem {
	CQChatPresentationController *chatPresentationController = [CQChatController defaultController].chatPresentationController;
	NSMutableArray *items = [chatPresentationController.standardToolbarItems mutableCopy];

	if (viewController == [CQChatController defaultController].chatNavigationController) {
		[_colloquiesPopoverController release];
		_colloquiesPopoverController = nil;

		NSAssert(_colloquiesBarButtonItem == barButtonItem, @"Bar button item was not the known Colloquies bar button item.");
		[_colloquiesBarButtonItem release];
		_colloquiesBarButtonItem = nil;
	}

	[items removeObjectIdenticalTo:barButtonItem];

	[chatPresentationController setStandardToolbarItems:items animated:NO];

	[items release];
}

#pragma mark -

- (void) showActionSheet:(UIActionSheet *) sheet {
	[self showActionSheet:sheet forSender:nil animated:YES];
}

- (void) showActionSheet:(UIActionSheet *) sheet forSender:(id) sender animated:(BOOL) animated {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_3_2
	if (sender && [[UIDevice currentDevice] isPadModel]) {
		id old = _visibleActionSheet;
		[old dismissWithClickedButtonIndex:[old cancelButtonIndex] animated:NO];
		[old release];
		_visibleActionSheet = nil;

		if ([sender isKindOfClass:[UIBarButtonItem class]]) {
			[sheet showFromBarButtonItem:sender animated:animated];
			_visibleActionSheet = [sheet retain];
		} else if ([sender isKindOfClass:[UIView class]]) {
			UIView *view = sender;
			[sheet showFromRect:view.bounds inView:view animated:animated];
			_visibleActionSheet = [sheet retain];
		}

		return;
	}
#endif

	UITabBar *tabBar = self.tabBarController.tabBar;
	if (tabBar && !self.modalViewController) {
		[sheet showFromTabBar:tabBar];
		return;
	}

	if ([sender isKindOfClass:[UIView class]]) {
		[sheet showInView:sender];
		return;
	}

	[sheet showInView:_mainViewController.view];
}

#pragma mark -

@synthesize mainViewController = _mainViewController;

- (UIViewController *) modalViewController {
	return _mainViewController.modalViewController;
}

- (void) presentModalViewController:(UIViewController *) modalViewController {
	[self presentModalViewController:modalViewController animated:YES singly:YES];
}

- (void) presentModalViewController:(UIViewController *) modalViewController animated:(BOOL) animated {
	[self presentModalViewController:modalViewController animated:animated singly:YES];
}

- (void) _presentModalViewControllerWithInfo:(NSDictionary *) info {
	UIViewController *modalViewController = [info objectForKey:@"modalViewController"];
	BOOL animated = [[info objectForKey:@"animated"] boolValue];

	[self presentModalViewController:modalViewController animated:animated singly:YES];
}

- (void) presentModalViewController:(UIViewController *) modalViewController animated:(BOOL) animated singly:(BOOL) singly {
	if (singly && self.modalViewController) {
		[self dismissModalViewControllerAnimated:animated];
		if (animated) {
			NSDictionary *info = [[NSDictionary alloc] initWithObjectsAndKeys:modalViewController, @"modalViewController", [NSNumber numberWithBool:animated], @"animated", nil];
			[self performSelector:@selector(_presentModalViewControllerWithInfo:) withObject:info afterDelay:0.5];
			[info release];
			return;
		}
	}

	[_mainViewController presentModalViewController:modalViewController animated:animated];
}

- (void) dismissModalViewControllerAnimated:(BOOL) animated {
	[_mainViewController dismissModalViewControllerAnimated:animated];
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

- (void) showHelp:(id) sender {
	CQWelcomeController *welcomeController = [[CQWelcomeController alloc] init];
	welcomeController.shouldShowOnlyHelpTopics = YES;

	[self presentModalViewController:welcomeController animated:YES];

	[welcomeController release];
}

- (void) showWelcome:(id) sender {
	CQWelcomeController *welcomeController = [[CQWelcomeController alloc] init];

	[self presentModalViewController:welcomeController animated:YES];

	[welcomeController release];
}

- (void) toggleConnections:(id) sender {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_3_2
	if (_connectionsPopoverController.popoverVisible)
		[_connectionsPopoverController dismissPopoverAnimated:YES];
	else
#endif
		[self showConnections:sender];
}

- (void) showConnections:(id) sender {
	if ([[UIDevice currentDevice] isPadModel]) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_3_2
		if (!_connectionsPopoverController)
			_connectionsPopoverController = [[UIPopoverController alloc] initWithContentViewController:[CQConnectionsController defaultController].connectionsNavigationController];

		if (!_connectionsPopoverController.popoverVisible) {
			[self dismissPopoversAnimated:NO];
			[_connectionsPopoverController presentPopoverFromBarButtonItem:_connectionsBarButtonItem permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
		}
#endif
	} else {
		[[CQConnectionsController defaultController].connectionsNavigationController popToRootViewControllerAnimated:NO];
		self.tabBarController.selectedViewController = [CQConnectionsController defaultController].connectionsNavigationController;
	}
}

- (void) toggleColloquies:(id) sender {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_3_2
	if (_colloquiesPopoverController.popoverVisible)
		[_colloquiesPopoverController dismissPopoverAnimated:YES];
	else
#endif
		[self showColloquies:sender];
}

- (void) showColloquies:(id) sender {
	if ([[UIDevice currentDevice] isPadModel]) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_3_2
		if (!UIInterfaceOrientationIsLandscape([UIDevice currentDevice].orientation)) {
			if (!_colloquiesPopoverController.popoverVisible) {
				[self dismissPopoversAnimated:NO];
				[_colloquiesPopoverController presentPopoverFromBarButtonItem:_colloquiesBarButtonItem permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
			}
		}
#endif
	} else {
		self.tabBarController.selectedViewController = [CQChatController defaultController].chatNavigationController;
		[[CQChatController defaultController].chatNavigationController popToRootViewControllerAnimated:YES];
	}
}

- (void) dismissPopoversAnimated:(BOOL) animated {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_3_2
	[_colloquiesPopoverController dismissPopoverAnimated:animated];
	[_connectionsPopoverController dismissPopoverAnimated:animated];

	id <CQChatViewController> controller = [CQChatController defaultController].visibleChatController;
	if ([controller respondsToSelector:@selector(dismissPopoversAnimated:)])
		[controller dismissPopoversAnimated:animated];
#endif
}

- (void) submitRunTime {
	NSTimeInterval runTime = ABS([_resumeDate timeIntervalSinceNow]);
	[[CQAnalyticsController defaultController] setObject:[NSNumber numberWithDouble:runTime] forKey:@"run-time"];
	[[CQAnalyticsController defaultController] synchronizeSynchronously];
}

#pragma mark -

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
	NSString *scheme = url.scheme;
#if !TARGET_IPHONE_SIMULATOR
	NSString *host = url.host;
	if ([host hasCaseInsensitiveSubstring:@"maps.google."])
		return NSLocalizedString(@"Maps", @"Maps application name");
	if ([host hasCaseInsensitiveSubstring:@"youtube."])
		return NSLocalizedString(@"YouTube", @"YouTube application name");
	if ([host hasCaseInsensitiveSubstring:@"phobos.apple."])
		return NSLocalizedString(@"iTunes", @"iTunes application name");
	if ([scheme isCaseInsensitiveEqualToString:@"mailto"])
		return NSLocalizedString(@"Mail", @"Mail application name");
#endif
	if ([scheme isCaseInsensitiveEqualToString:@"http"] || [scheme isCaseInsensitiveEqualToString:@"https"])
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

	BOOL loadLastURL = [url.absoluteString isCaseInsensitiveEqualToString:@"about:last"];
	if (loadLastURL)
		openWithBrowser = YES;

	if (url && !loadLastURL && ![self canOpenURL:url])
		return NO;

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
	[_mainViewController presentModalViewController:browserController animated:YES];

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

- (void) tabBarController:(UITabBarController *) tabBarController didSelectViewController:(UIViewController *) viewController {
	[[NSUserDefaults standardUserDefaults] setInteger:tabBarController.selectedIndex forKey:@"CQSelectedTabIndex"];
}

#pragma mark -

- (UIColor *) tintColor {
	if ([[UIDevice currentDevice] isPadModel])
		return nil;

	NSString *style = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQChatTranscriptStyle"];
	if ([style hasSuffix:@"-dark"])
		return [UIColor blackColor];
	if ([style isEqualToString:@"notes"])
		return [UIColor colorWithRed:0.224 green:0.082 blue:0. alpha:1.];
	return nil;
}

#pragma mark -

- (void) hideTabBarWithTransition:(BOOL) transition {
#if ENABLE(SECRETS)
	UITabBarController *tabBarController = self.tabBarController;
	if (!tabBarController)
		return;

	if (!_showingTabBar)
		return;

	[tabBarController performPrivateSelector:@"hideBarWithTransition:" withUnsignedInteger:(transition ? UITabBarTransitionSlide : UITabBarTransitionNone)];

	_showingTabBar = NO;
#endif
}

- (void) showTabBarWithTransition:(BOOL) transition {
#if ENABLE(SECRETS)
	UITabBarController *tabBarController = self.tabBarController;
	if (!tabBarController)
		return;

	if (_showingTabBar)
		return;

	[tabBarController performPrivateSelector:@"showBarWithTransition:" withUnsignedInteger:(transition ? UITabBarTransitionSlide : UITabBarTransitionNone)];

	_showingTabBar = YES;
#endif
}

#pragma mark -

- (BOOL) areNotificationBadgesAllowed {
	return (!_deviceToken || [self enabledRemoteNotificationTypes] & UIRemoteNotificationTypeBadge);
}

- (BOOL) areNotificationSoundsAllowed {
	return (!_deviceToken || [self enabledRemoteNotificationTypes] & UIRemoteNotificationTypeSound);
}

- (BOOL) areNotificationAlertsAllowed {
	return (!_deviceToken || [self enabledRemoteNotificationTypes] & UIRemoteNotificationTypeAlert);
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_4_0
- (void) presentLocalNotificationNow:(UILocalNotification *) notification {
	if (![self areNotificationAlertsAllowed])
		notification.alertBody = nil;
	if (![self areNotificationSoundsAllowed])
		notification.soundName = nil;
	if (![self areNotificationBadgesAllowed])
		notification.applicationIconBadgeNumber = 0;
	[super presentLocalNotificationNow:notification];
}
#endif

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
