#import "CQColloquyApplication.h"

#import "CQAlertView.h"
#import "CQAnalyticsController.h"
#import "CQChatController.h"
#import "CQChatCreationViewController.h"
#import "CQConnectionsController.h"
#import "CQConnectionsNavigationController.h"
#import "CQRootContainerViewController.h"
#import "CQWelcomeController.h"

#import "NSNotificationAdditions.h"
#import "NSRegularExpressionAdditions.h"
#import "UIApplicationAdditions.h"
#import "UIFontAdditions.h"

#import <SafariServices/SafariServices.h>
#import <UserNotifications/UserNotifications.h>

#import <HockeySDK/HockeySDK.h>

static NSMutableArray <NSString *> *highlightWords;

NS_ASSUME_NONNULL_BEGIN

NSString *CQColloquyApplicationDidRecieveDeviceTokenNotification = @"CQColloquyApplicationDidRecieveDeviceTokenNotification";

#define BrowserAlertTag 1

@interface CQColloquyApplication () <UIApplicationDelegate, CQAlertViewDelegate, BITHockeyManagerDelegate, UNUserNotificationCenterDelegate>
@end

@implementation CQColloquyApplication {
	UIWindow *_mainWindow;
	CQRootContainerViewController *_rootContainerViewController;
	UIToolbar *_toolbar;
	NSDate *_launchDate;
	NSDate *_resumeDate;
	NSString *_deviceToken;
	NSUInteger _networkIndicatorStack;
	CQActionSheet *_visibleActionSheet;
	NSNumber *_oldSwipeOrientationValue;
	BOOL _userDefaultsChanged;
}

+ (CQColloquyApplication *) sharedApplication {
	return (CQColloquyApplication *)[UIApplication sharedApplication];
}

- (instancetype) init {
	if (!(self = [super init]))
		return nil;

	_launchDate = [[NSDate alloc] init];
	_resumeDate = [_launchDate copy];

	return self;
}

#pragma mark -

- (UIWindow *__nullable) window {
	return _mainWindow;
}

#pragma mark -

- (NSSet *) handledURLSchemes {
	static NSMutableSet *schemes;
	if (!schemes) {
		schemes = [[NSMutableSet alloc] init];

		NSArray <NSString *> *urlTypes = [NSBundle mainBundle].infoDictionary[@"CFBundleURLTypes"];
		for (NSDictionary *type in urlTypes) {
			NSArray <NSString *> *schemesForType = type[@"CFBundleURLSchemes"];
			for (NSString *scheme in schemesForType)
				[schemes addObject:scheme.lowercaseString];
		}
	}

	return schemes;
}

- (NSArray <NSString *> *) highlightWords {
	if (!highlightWords) {
		highlightWords = [[NSMutableArray alloc] init];

		NSString *highlightWordsString = [[CQSettingsController settingsController] stringForKey:@"CQHighlightWords"];
		if (highlightWordsString.length) {
			NSRegularExpression *regex = [NSRegularExpression cachedRegularExpressionWithPattern:@"(?<=\\s|^)[/\"'](.*?)[/\"'](?=\\s|$)" options:NSRegularExpressionCaseInsensitive error:nil];
			for (NSTextCheckingResult *result in [regex matchesInString:highlightWordsString options:(NSMatchingOptions)NSMatchingReportCompletion range:NSMakeRange(0, highlightWordsString.length)])
				[highlightWords addObject:[highlightWordsString substringWithRange:[result rangeAtIndex:1]]];

			highlightWordsString = [highlightWordsString stringByReplacingOccurrencesOfRegex:@"(?<=\\s|^)[/\"'](.*?)[/\"'](?=\\s|$)" withString:@""];

			[highlightWords addObjectsFromArray:[highlightWordsString componentsSeparatedByString:@" "]];
			[highlightWords removeObject:@""];
		}
	}

	return highlightWords;
}

- (void) updateAnalytics {
	CQAnalyticsController *analyticsController = [CQAnalyticsController defaultController];

	[analyticsController setObject:[[[CQSettingsController settingsController] stringForKey:@"CQChatTranscriptStyle"] lowercaseString] forKey:@"transcript-style"];

	NSString *information = ([[CQSettingsController settingsController] boolForKey:@"CQGraphicalEmoticons"] ? @"emoji" : @"text");
	[analyticsController setObject:information forKey:@"emoticon-style"];

	information = ([[CQSettingsController settingsController] boolForKey:@"CQDisableLandscape"] ? @"0" : @"1");
	[analyticsController setObject:information forKey:@"landscape"];

	information = [[NSLocale autoupdatingCurrentLocale] localeIdentifier];
	[analyticsController setObject:information forKey:@"locale"];

	[analyticsController setObject:[[[CQSettingsController settingsController] stringForKey:@"CQChatAutocompleteBehavior"] lowercaseString] forKey:@"autocomplete-behavior"];

	[analyticsController setObject:[[CQSettingsController settingsController] objectForKey:@"CQMultitaskingTimeout"] forKey:@"multitasking-timeout"];

	NSInteger showNotices = [[CQSettingsController settingsController] integerForKey:@"JVChatAlwaysShowNotices"];
	information = (!showNotices ? @"auto" : (showNotices == 1 ? @"all" : @"none"));
	[analyticsController setObject:information forKey:@"notices-behavior"];

	information = ([[[CQSettingsController settingsController] stringForKey:@"JVQuitMessage"] hasCaseInsensitiveSubstring:@"Colloquy for"] ? @"default" : @"custom");
	[analyticsController setObject:information forKey:@"quit-message"];
}

- (void) setDefaultMessageStringForKey:(NSString *) key {
	NSString *message = [[CQSettingsController settingsController] stringForKey:key];
	if ([message hasCaseInsensitiveSubstring:@"Colloquy for iPhone"]) {
		message = [NSString stringWithFormat:NSLocalizedString(@"Colloquy for %@ - http://colloquy.mobi", @"Status message, with the device name inserted"), [UIDevice currentDevice].localizedModel];
		[[CQSettingsController settingsController] setObject:message forKey:key];
	}
}

- (void) userDefaultsChanged {
	if (![NSThread isMainThread])
		return;

	highlightWords = nil;

	NSNumber *newSwipeOrientationValue = [[CQSettingsController settingsController] objectForKey:@"CQSplitSwipeOrientations"];

	if (![_oldSwipeOrientationValue isEqualToNumber:newSwipeOrientationValue]) {
		_oldSwipeOrientationValue = [newSwipeOrientationValue copy];

		if (self.modalViewController)
			_userDefaultsChanged = YES;
		else [self _reloadSplitViewController];

		BOOL disableSingleSwipe = (![[UIDevice currentDevice] isPadModel] && !(self.splitViewController.displayMode == UISplitViewControllerDisplayModePrimaryHidden || self.splitViewController.displayMode == UISplitViewControllerDisplayModePrimaryOverlay));
		if (disableSingleSwipe)
			[[CQSettingsController settingsController] setInteger:0 forKey:@"CQSingleFingerSwipe"];
	}

	[self updateAnalytics];
}

- (void) performDeferredLaunchWork {
#if !TARGET_IPHONE_SIMULATOR
	NSString *hockeyappIdentifier = @"Hockeyapp_App_Identifier";
	// Hacky check to make sure the identifier was replaced with a string that isn't ""
	if (![hockeyappIdentifier hasPrefix:@"Hockeyapp"]) {
		[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:hockeyappIdentifier delegate:self];
		[BITHockeyManager sharedHockeyManager].disableInstallTracking = YES;

		[[BITHockeyManager sharedHockeyManager] startManager];
	}
#endif

	[self cq_beginReachabilityMonitoring];

	NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
	NSString *version = infoDictionary[@"CFBundleShortVersionString"];

	if (![[[CQSettingsController settingsController] stringForKey:@"CQLastVersionUsed"] isEqualToString:version]) {
		NSString *bundleVersion = infoDictionary[@"CFBundleVersion"];
		NSString *displayVersion = nil;
		if (bundleVersion.length)
			displayVersion = [NSString stringWithFormat:@"%@ (%@)", version, bundleVersion];
		else displayVersion = version;
		[[CQSettingsController settingsController] setObject:displayVersion forKey:@"CQCurrentVersion"];

		if (![[CQSettingsController settingsController] boolForKey:@"JVSetUpDefaultQuitMessage"]) {
			[self setDefaultMessageStringForKey:@"JVQuitMessage"];
			[[CQSettingsController settingsController] setBool:YES forKey:@"JVSetUpDefaultQuitMessage"];
		}

		if (![[CQSettingsController settingsController] boolForKey:@"JVSetUpDefaultAwayMessage"]) {
			[self setDefaultMessageStringForKey:@"CQAwayStatus"];
			[[CQSettingsController settingsController] setBool:YES forKey:@"JVSetUpDefaultAwayMessage"];
		}

		if (![CQConnectionsController defaultController].connections.count && ![CQConnectionsController defaultController].bouncers.count)
			[self showWelcome:nil];

		[[CQSettingsController settingsController] setObject:version forKey:@"CQLastVersionUsed"];
	}

	CQAnalyticsController *analyticsController = [CQAnalyticsController defaultController];

	NSString *information = infoDictionary[@"CFBundleShortVersionString"];
	[analyticsController setObject:information forKey:@"application-version"];

	information = infoDictionary[@"CFBundleVersion"];
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

	[analyticsController setObject:([UIDevice currentDevice].multitaskingSupported ? @"1" : @"0") forKey:@"multitasking-supported"];
	[analyticsController setObject:@([UIScreen mainScreen].scale) forKey:@"screen-scale-factor"];

	if (_deviceToken.length)
		[analyticsController setObject:_deviceToken forKey:@"device-push-token"];

	[self updateAnalytics];

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(userDefaultsChanged) name:CQSettingsDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_accessibilityDarkerSystemColorsStatus:) name:UIAccessibilityDarkerSystemColorsStatusDidChangeNotification object:nil];
}

- (void) handleNotificationWithUserInfo:(NSDictionary *__nullable) userInfo {
	if (!userInfo.count)
		return;

	NSString *connectionServer = userInfo[@"s"];
	NSString *connectionIdentifier = userInfo[@"c"];
	if (connectionServer.length || connectionIdentifier.length) {
		NSString *roomName = userInfo[@"r"];
		NSString *senderNickname = userInfo[@"n"];
		NSString *action = userInfo[@"a"];

		MVChatConnection *connection = nil;

		if (connectionIdentifier.length)
			connection = [[CQConnectionsController defaultController] connectionForUniqueIdentifier:connectionIdentifier];
		if (!connection && connectionServer.length)
			connection = [[CQConnectionsController defaultController] connectionForServerAddress:connectionServer];

		if (connection) {
			[connection connectAppropriately];

			BOOL animationEnabled = [UIView areAnimationsEnabled];
			[UIView setAnimationsEnabled:NO];

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

- (void) _accessibilityDarkerSystemColorsStatus:(NSNotification *) notification {
	[self _applyTintColor];
}

- (void) _applyTintColor {
	BOOL darkerColorsEnabled = UIAccessibilityDarkerSystemColorsEnabled();

	// rgb(109, 22, 101) == hsb(306°, 80%, 43%)
	CGFloat hue = 306 * (darkerColorsEnabled ? 1.13 : 1.0);
	CGFloat saturation = .8;
	CGFloat brightness = .43 * (darkerColorsEnabled ? 0.88 : 1.0);

	_mainWindow.tintColor = [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1.0];
}

#pragma mark -

- (BOOL)_handleOpenURL:(NSURL *)url {
	if ([url.scheme isCaseInsensitiveEqualToString:@"colloquy"]) {
		[[NSNotificationCenter chatCenter] postNotificationName:@"CQPocketShouldConvertTokenFromTokenNotification" object:nil];

		return YES;
	}

	return [[CQConnectionsController defaultController] handleOpenURL:url];
}

- (void) _reloadSplitViewController {
	[_rootContainerViewController buildRootViewController];

	_mainViewController = _rootContainerViewController;
	_mainWindow.rootViewController = _mainViewController;
}

#pragma mark -

- (BOOL) application:(UIApplication *) application willFinishLaunchingWithOptions:(NSDictionary *__nullable) launchOptions {
	NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]];
	[[CQSettingsController settingsController] registerDefaults:defaults];

	NSString *fontName = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQChatTranscriptFont"];
	UIFont *font = [UIFont fontWithName:fontName size:12.];
	UIFont *systemFont = [UIFont systemFontOfSize:12.];

	if (!font || [font.familyName isCaseInsensitiveEqualToString:systemFont.familyName])
		[UIFont cq_loadRemoteFontWithName:fontName completionHandler:NULL];

	if ([[NSUserDefaults standardUserDefaults] doubleForKey:@"CQMultitaskingTimeout"] == 600.)
		[[NSUserDefaults standardUserDefaults] setDouble:300. forKey:@"CQMultitaskingTimeout"];

	_deviceToken = [[CQSettingsController settingsController] stringForKey:@"CQPushDeviceToken"];

	[CQConnectionsController defaultController];
	[CQChatController defaultController];

	_mainWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
	_rootContainerViewController = [[CQRootContainerViewController alloc] init];

	// UNUserNotificationCenter required (requires?) this to be done before app…:didFinishLaunching…: return's
	[UNUserNotificationCenter currentNotificationCenter].delegate = self;

	return YES;
}

- (BOOL) application:(UIApplication *) application didFinishLaunchingWithOptions:(NSDictionary *__nullable) launchOptions {
	if (![[CQChatController defaultController] hasPendingChatController] && [UIDevice currentDevice].isPadModel)
		[[CQChatController defaultController] setFirstChatController];

	[self _applyTintColor];

	[self userDefaultsChanged];

	[self _reloadSplitViewController];

	[_mainWindow makeKeyAndVisible];

	if ([[CQChatController defaultController] hasPendingChatController])
		[[CQChatController defaultController] showPendingChatControllerAnimated:NO];

#if !SYSTEM(TV)
	[self handleNotificationWithUserInfo:launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey]];
#endif

	[self performSelector:@selector(performDeferredLaunchWork) withObject:nil afterDelay:1.];

	return YES;
}

- (void) applicationWillEnterForeground:(UIApplication *) application {
#if !SYSTEM(TV)
	[[UNUserNotificationCenter currentNotificationCenter] removeAllPendingNotificationRequests];
#endif
}

- (void) applicationWillResignActive:(UIApplication *) application {
	_oldSwipeOrientationValue = [[CQSettingsController settingsController] objectForKey:@"CQSplitSwipeOrientations"];
}

- (void) userNotificationCenter:(UNUserNotificationCenter *) center didReceiveNotificationResponse:(UNNotificationResponse *) response withCompletionHandler:(void(^)(void)) completionHandler {
	[self handleNotificationWithUserInfo:response.notification.request.content.userInfo];

	self.applicationIconBadgeNumber = response.notification.request.content.badge.integerValue;
}

#if !SYSTEM(TV)
- (void) application:(UIApplication *) application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *) deviceToken {
	if (!deviceToken.length) {
		[[CQAnalyticsController defaultController] setObject:nil forKey:@"device-push-token"];
		[[CQSettingsController settingsController] removeObjectForKey:@"CQPushDeviceToken"];

		_deviceToken = nil;
		return;
	}

	const unsigned *tokenData = deviceToken.bytes;
	NSString *deviceTokenString = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x", ntohl(tokenData[0]), ntohl(tokenData[1]), ntohl(tokenData[2]), ntohl(tokenData[3]), ntohl(tokenData[4]), ntohl(tokenData[5]), ntohl(tokenData[6]), ntohl(tokenData[7])];

	if ([_deviceToken isEqualToString:deviceTokenString] || !deviceTokenString)
		return;

	[[CQAnalyticsController defaultController] setObject:deviceTokenString forKey:@"device-push-token"];
	[[CQSettingsController settingsController] setObject:deviceTokenString forKey:@"CQPushDeviceToken"];

	_deviceToken = deviceTokenString;

	[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:CQColloquyApplicationDidRecieveDeviceTokenNotification object:self userInfo:@{@"deviceToken": deviceTokenString}];
}

- (void) application:(UIApplication *) application didFailToRegisterForRemoteNotificationsWithError:(NSError *) error {
	NSLog(@"Error during remote notification registration. Error: %@", error);
}
#endif

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
	return [self _handleOpenURL:url];
}

- (void) applicationWillTerminate:(UIApplication *) application {
#if !SYSTEM(TV)
	[UIApplication sharedApplication].applicationIconBadgeNumber = 0;

	self.appIconOptions = CQAppIconOptionConnect;
#endif

	[self submitRunTime];
}

#pragma mark -

- (void) showActionSheet:(CQActionSheet *) sheet {
	[self showActionSheet:sheet forSender:nil animated:YES];
}

- (void) showActionSheet:(CQActionSheet *) sheet fromPoint:(CGPoint) point {
	[self showActionSheet:sheet forSender:nil orFromPoint:point animated:YES];
}

- (void) showActionSheet:(CQActionSheet *) sheet forSender:(__nullable id) sender animated:(BOOL) animated {
	[self showActionSheet:sheet forSender:sender orFromPoint:CGPointZero animated:animated];
}

- (void) showActionSheet:(CQActionSheet *) sheet forSender:(__nullable id) sender orFromPoint:(CGPoint) point animated:(BOOL) animated {
	[sheet showforSender:sender orFromPoint:point animated:animated];
}

#pragma mark -

- (UIViewController *) modalViewController {
	return _mainViewController.presentedViewController;
}

- (void) presentModalViewController:(UIViewController *) modalViewController {
	[self presentModalViewController:modalViewController animated:YES singly:YES];
}

- (void) presentModalViewController:(UIViewController *) modalViewController animated:(BOOL) animated {
	[self presentModalViewController:modalViewController animated:animated singly:YES];
}

- (void) _presentModalViewControllerWithInfo:(NSDictionary *) info {
	UIViewController *modalViewController = info[@"modalViewController"];
	BOOL animated = [info[@"animated"] boolValue];

	[self presentModalViewController:modalViewController animated:animated singly:YES];
}

- (void) presentModalViewController:(UIViewController *) modalViewController animated:(BOOL) animated singly:(BOOL) singly {
	if (singly && self.modalViewController) {
		[self dismissModalViewControllerAnimated:animated];
		if (animated) {
			[self performSelector:@selector(_presentModalViewControllerWithInfo:) withObject:@{
				@"modalViewController": modalViewController,
				@"animated": @(animated)
			} afterDelay:0.25];
			return;
		}
	}

	[_mainViewController presentViewController:modalViewController animated:animated completion:NULL];
}

- (void) dismissModalViewControllerAnimated:(BOOL) animated {
	[_mainViewController dismissViewControllerAnimated:animated completion:NULL];

	if (_userDefaultsChanged) {
		_userDefaultsChanged = NO;

		[self _reloadSplitViewController];
	}
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

- (void) showHelp:(__nullable id) sender {
	CQWelcomeController *welcomeController = [[CQWelcomeController alloc] init];
	welcomeController.shouldShowOnlyHelpTopics = YES;

	[self presentModalViewController:welcomeController animated:YES];
}

- (void) showWelcome:(__nullable id) sender {
	CQWelcomeController *welcomeController = [[CQWelcomeController alloc] init];

	[self presentModalViewController:welcomeController animated:YES];
}

- (void) toggleConnections:(__nullable id) sender {
	[self showConnections:sender];
}

- (void) showConnections:(__nullable id) sender {
	[[CQConnectionsController defaultController].connectionsNavigationController popToRootViewControllerAnimated:NO];
}

- (void) dismissPopoversAnimated:(BOOL) animated {
	id <CQChatViewController> controller = [CQChatController defaultController].visibleChatController;
	if ([controller respondsToSelector:@selector(dismissPopoversAnimated:)])
		[controller dismissPopoversAnimated:animated];
}

- (void) submitRunTime {
	NSTimeInterval runTime = ABS([_resumeDate timeIntervalSinceNow]);
	[[CQAnalyticsController defaultController] setObject:@(runTime) forKey:@"run-time"];
	[[CQAnalyticsController defaultController] synchronize];
}

#pragma mark -

- (BOOL) isSpecialApplicationURL:(NSURL *) url {
#if !TARGET_IPHONE_SIMULATOR
	return (url && ([url.host hasCaseInsensitiveSubstring:@"phobos.apple."]));
#else
	return NO;
#endif
}

- (NSString *) applicationNameForURL:(NSURL *) url {
	if (!url)
		return @"";
	NSString *scheme = url.scheme;
#if !TARGET_IPHONE_SIMULATOR
	NSString *host = url.host;
	if ([host hasCaseInsensitiveSubstring:@"phobos.apple."])
		return NSLocalizedString(@"iTunes", @"iTunes application name");
	if ([scheme isCaseInsensitiveEqualToString:@"mailto"])
		return NSLocalizedString(@"Mail", @"Mail application name");
#endif
	if ([scheme isCaseInsensitiveEqualToString:@"http"] || [scheme isCaseInsensitiveEqualToString:@"https"])
		return NSLocalizedString(@"Safari", @"Safari application name");
	return @"";
}

- (void) openURL:(NSURL*) url options:(NSDictionary<NSString *, id> *) options completionHandler:(void (^ __nullable)(BOOL success)) completionHandler {
	[self openURL:url options:options completionHandler:completionHandler promptForExternal:YES];
}

- (void) openURL:(NSURL *) url options:(NSDictionary<NSString *,id> *) options completionHandler:(void (^)(BOOL)) completionHandler promptForExternal:(BOOL) prompt {
	if ([[CQConnectionsController defaultController] handleOpenURL:url]) {
		completionHandler(YES);
		return;
	}

	if ([self isSpecialApplicationURL:url]) {
		if (!prompt) {
			[super openURL:url options:options completionHandler:completionHandler];
			return;
		}

		CQAlertView *alert = [[CQAlertView alloc] init];

		alert.tag = BrowserAlertTag;

		NSString *applicationName = [self applicationNameForURL:url];
		if (applicationName)
			alert.title = [NSString stringWithFormat:NSLocalizedString(@"Open Link in %@?", @"Open link in app alert title"), applicationName];
		else alert.title = NSLocalizedString(@"Open Link?", @"Open link alert title");

		alert.message = NSLocalizedString(@"Opening this link will close Colloquy.", @"Opening link alert message");
		alert.delegate = self;

		alert.cancelButtonIndex = [alert addButtonWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title")];

		[alert associateObject:url forKey:@"userInfo"];
		[alert addButtonWithTitle:NSLocalizedString(@"Open", @"Open button title")];

		[alert show];
	} else {
		NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];

		BOOL isWebLink = [components.scheme isCaseInsensitiveEqualToString:@"http"] || [components.scheme isCaseInsensitiveEqualToString:@"https"];
		NSString *selectedBrowser = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQSelectedBrowser"];
		if (!isWebLink || [selectedBrowser isEqualToString:@"Safari"]) {
			[super openURL:url options:options completionHandler:completionHandler];

			return;
		}

		if ([selectedBrowser isEqualToString:@"Colloquy"]) {
			SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:url];
			[self.window.rootViewController presentViewController:safariViewController animated:YES completion:nil];

			return;
		}

		NSURL *nextURL = nil;
		if ([selectedBrowser isEqualToString:@"Chrome"]) {
			components.scheme = [components.scheme stringByReplacingOccurrencesOfString:@"http" withString:@"googlechrome" options:NSCaseInsensitiveSearch | NSAnchoredSearch range:NSMakeRange(0, components.scheme.length)];

			nextURL = components.URL;
		} else if ([selectedBrowser isEqualToString:@"Firefox"]) {
			NSURLComponents *nextComponents = [[NSURLComponents alloc] initWithString:@"firefox://open-url"];
			nextComponents.queryItems = @[
				[NSURLQueryItem queryItemWithName:@"url" value:url.absoluteString]
			];

			nextURL = nextComponents.URL;
		} else if ([selectedBrowser isEqualToString:@"Brave"]) {
			NSURLComponents *nextComponents = [[NSURLComponents alloc] initWithString:@"brave://open-url"];
			nextComponents.queryItems = @[
				[NSURLQueryItem queryItemWithName:@"url" value:url.absoluteString]
			];

			nextURL = nextComponents.URL;
		}

		[super openURL:nextURL options:options completionHandler:^(BOOL success) {
			if (completionHandler)
				completionHandler(success);

			if (!success) {
				[self redirectURLFromUnhandledAppNamed:selectedBrowser toSafari:url];
			}
		}];

	}
}

- (void) redirectURLFromUnhandledAppNamed:(NSString *) appName toSafari:(NSURL *) url {
	CQAlertView *alert = [[CQAlertView alloc] init];
	alert.delegate = self;
	alert.tag = BrowserAlertTag;
	alert.title = NSLocalizedString(@"Browser Error", @"Browser Error Alert Title");
	alert.message = [NSString stringWithFormat:NSLocalizedString(@"There was a problem opening '%@' in '%@'. Continue with Safari?", @"Browser Error message text containing URL and App Name"), url.absoluteString, appName];
	alert.cancelButtonIndex = [alert addButtonWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title")];
	[alert associateObject:url forKey:@"userInfo"];
	[alert addButtonWithTitle:NSLocalizedString(@"Continue", @"Continue button title")];
	[alert show];
}

#pragma mark -

- (void) alertView:(CQAlertView *) alertView clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (alertView.tag != BrowserAlertTag || alertView.cancelButtonIndex == buttonIndex)
		return;
	[super openURL:[alertView associatedObjectForKey:@"userInfo"] options:@{} completionHandler:nil];
}

#pragma mark -

- (UIColor *__nullable) tintColor {
	if ([UIDevice currentDevice].isPadModel)
		return nil;

	NSString *style = [[CQSettingsController settingsController] stringForKey:@"CQChatTranscriptStyle"];
	if ([style hasSuffix:@"-dark"])
		return [UIColor blackColor];
	if ([style isEqualToString:@"notes"])
		return [UIColor colorWithRed:0.224 green:0.082 blue:0. alpha:1.];
	return nil;
}

#pragma mark -

#if !SYSTEM(TV)
- (void) updateAppShortcuts {
	CQAppIconOptions options = CQAppIconOptionNone;

	if ([CQConnectionsController defaultController].connections.count) {
		if ([CQConnectionsController defaultController].connectedConnections.count != [CQConnectionsController defaultController].connections.count)
			options |= CQAppIconOptionConnect;
		options |= CQAppIconOptionNewChat;
		options |= CQAppIconOptionNewPrivateChat;
	}

	options |= CQAppIconOptionNewConnection;

	self.appIconOptions = options;
}

- (void) setAppIconOptions:(CQAppIconOptions) appIconOptions {
	_appIconOptions = appIconOptions;

	NSMutableArray <UIMutableApplicationShortcutItem *> *options = [NSMutableArray array];
	if ((appIconOptions & CQAppIconOptionNewConnection) == CQAppIconOptionNewConnection)
		[options addObject:[[UIMutableApplicationShortcutItem alloc] initWithType:@"CQAppShortcutNewConnection" localizedTitle:NSLocalizedString(@"New Connection", @"New Connection shortcut title")]];
	if ((appIconOptions & CQAppIconOptionConnect) == CQAppIconOptionConnect)
		[options addObject:[[UIMutableApplicationShortcutItem alloc] initWithType:@"CQAppShortcutConnect" localizedTitle:NSLocalizedString(@"Connect", @"Connect")]];
	if ((appIconOptions & CQAppIconOptionNewChat) == CQAppIconOptionNewChat)
		[options addObject:[[UIMutableApplicationShortcutItem alloc] initWithType:@"CQAppShortcutNewChat" localizedTitle:NSLocalizedString(@"Join Chat Room", @"Join Chat Room shortcut title")]];
	if ((appIconOptions & CQAppIconOptionNewPrivateChat) == CQAppIconOptionNewPrivateChat)
		[options addObject:[[UIMutableApplicationShortcutItem alloc] initWithType:@"CQAppShortcutNewPrivateChat" localizedTitle:NSLocalizedString(@"Send Private Message", @"Send Private Message shortcut title")]];

	self.shortcutItems = options;
}

- (void) application:(UIApplication *) application performActionForShortcutItem:(UIApplicationShortcutItem *) shortcutItem completionHandler:(void(^)(BOOL succeeded)) completionHandler {
	if ([shortcutItem.type isEqualToString:@"CQAppShortcutConnect"])
		[[CQConnectionsController defaultController] openAllConnections];
	else if ([shortcutItem.type isEqualToString:@"CQAppShortcutNewChat"]) {
		CQChatCreationViewController *creationViewController = [[CQChatCreationViewController alloc] init];
		creationViewController.roomTarget = YES;

		[self presentModalViewController:creationViewController animated:YES];
	} else if ([shortcutItem.type isEqualToString:@"CQAppShortcutNewPrivateChat"]) {
		CQChatCreationViewController *creationViewController = [[CQChatCreationViewController alloc] init];
		creationViewController.roomTarget = NO;

		[self presentModalViewController:creationViewController animated:YES];
	} else if ([shortcutItem.type isEqualToString:@"CQAppShortcutNewConnection"]) {
		[[CQConnectionsController defaultController] showConnectionCreationView:nil];
	}

	[self updateAppShortcuts];
}

#pragma mark -

- (void) registerForNotificationTypes:(UNAuthorizationOptions) types {
	[[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:types completionHandler:^(BOOL granted, NSError * _Nullable error) {
		if (granted) {
			[self registerForRemoteNotifications];
		}
	}];
}

- (void) registerForPushNotifications {
#if !TARGET_IPHONE_SIMULATOR
	static BOOL registeredForPush;
	if (!registeredForPush) {

		[self registerForNotificationTypes:UNNotificationPresentationOptionBadge | UNNotificationPresentationOptionSound | UNNotificationPresentationOptionAlert];
		registeredForPush = YES;
	}
#endif
}
#endif
@end

NS_ASSUME_NONNULL_END
