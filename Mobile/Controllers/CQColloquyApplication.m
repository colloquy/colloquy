#import "CQColloquyApplication.h"

#import "CQAlertView.h"
#import "CQAnalyticsController.h"
#import "CQChatController.h"
#import "CQConnectionsController.h"
#import "CQConnectionsNavigationController.h"
#import "CQRootContainerViewController.h"
#import "CQWelcomeController.h"

#import "NSNotificationAdditions.h"
#import "NSRegularExpressionAdditions.h"
#import "UIApplicationAdditions.h"
#import "UIFontAdditions.h"

#import <HockeySDK/HockeySDK.h>

NS_ASSUME_NONNULL_BEGIN

NSString *CQColloquyApplicationDidRecieveDeviceTokenNotification = @"CQColloquyApplicationDidRecieveDeviceTokenNotification";

#define BrowserAlertTag 1

static NSMutableArray *highlightWords;

@interface CQColloquyApplication () <UIApplicationDelegate, UIAlertViewDelegate, BITHockeyManagerDelegate>
@end

@implementation CQColloquyApplication {
	UIWindow *_mainWindow;
	CQRootContainerViewController *_rootContainerViewController;
	UIViewController *_overlappingPresentationViewController;
	UIToolbar *_toolbar;
	NSDate *_launchDate;
	NSDate *_resumeDate;
	NSString *_deviceToken;
	NSUInteger _networkIndicatorStack;
	UIActionSheet *_visibleActionSheet;
	NSNumber *_oldSwipeOrientationValue;
	BOOL _userDefaultsChanged;
	UIAlertController *_alertController;
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

		NSArray *urlTypes = [NSBundle mainBundle].infoDictionary[@"CFBundleURLTypes"];
		for (NSDictionary *type in urlTypes) {
			NSArray *schemesForType = type[@"CFBundleURLSchemes"];
			for (NSString *scheme in schemesForType)
				[schemes addObject:scheme.lowercaseString];
		}
	}

	return schemes;
}

- (NSArray *) highlightWords {
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
		else [self reloadSplitViewController];

		BOOL disableSingleSwipe = (![[UIDevice currentDevice] isPadModel] && !(self.splitViewController.displayMode == UISplitViewControllerDisplayModePrimaryHidden || self.splitViewController.displayMode == UISplitViewControllerDisplayModePrimaryOverlay));
		if (disableSingleSwipe)
			[[CQSettingsController settingsController] setInteger:0 forKey:@"CQSingleFingerSwipe"];
	}

	[self updateAnalytics];
}

- (void) performDeferredLaunchWork {
	NSString *hockeyappIdentifier = @"Hockeyapp_App_Identifier";
	// Hacky check to make sure the identifier was replaced with a string that isn't ""
	if (![hockeyappIdentifier hasPrefix:@"Hockeyapp"]) {
		[[BITHockeyManager sharedHockeyManager] configureWithIdentifier:hockeyappIdentifier delegate:self];
		[BITHockeyManager sharedHockeyManager].disableInstallTracking = YES;

		[[BITHockeyManager sharedHockeyManager] startManager];
	}

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
}

- (void) handleNotificationWithUserInfo:(NSDictionary *) userInfo {
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

- (void) reloadSplitViewController {
	[_rootContainerViewController buildRootViewController];

	_mainViewController = _rootContainerViewController;
	_mainWindow.rootViewController = _mainViewController;
}

- (BOOL) application:(UIApplication *) application willFinishLaunchingWithOptions:(NSDictionary *__nullable) launchOptions {
	NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]];
	[[CQSettingsController settingsController] registerDefaults:defaults];

	NSString *fontName = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQChatTranscriptFont"];
	UIFont *font = [UIFont fontWithName:fontName size:12.];
	UIFont *systemFont = [UIFont systemFontOfSize:12.];
	if ((!font || [font.familyName isCaseInsensitiveEqualToString:systemFont.familyName]) && [[UIFont cq_availableRemoteFontNames] containsObject:fontName])
		[UIFont cq_loadFontWithName:fontName withCompletionHandler:NULL];

	if ([[NSUserDefaults standardUserDefaults] doubleForKey:@"CQMultitaskingTimeout"] == 600.)
		[[NSUserDefaults standardUserDefaults] setDouble:300. forKey:@"CQMultitaskingTimeout"];

	_deviceToken = [[CQSettingsController settingsController] stringForKey:@"CQPushDeviceToken"];

	[CQConnectionsController defaultController];
	[CQChatController defaultController];

	_mainWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
	_rootContainerViewController = [[CQRootContainerViewController alloc] init];

	return YES;
}

- (BOOL) application:(UIApplication *) application didFinishLaunchingWithOptions:(NSDictionary *__nullable) launchOptions {
	if (![[CQChatController defaultController] hasPendingChatController] && [UIDevice currentDevice].isPadModel)
		[[CQChatController defaultController] setFirstChatController];

	_mainWindow.tintColor = [UIColor colorWithRed:0.427 green:0.086 blue:0.396 alpha:1];
	if (UIAccessibilityDarkerSystemColorsEnabled()) {
		CGFloat hue, saturation, brightness, alpha = 0.;
		[_mainWindow.tintColor getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
		_mainWindow.tintColor = [UIColor colorWithHue:hue saturation:saturation * 1.13 brightness:brightness * .88 alpha:alpha];
	}

	[self userDefaultsChanged];

	[self reloadSplitViewController];

	[_mainWindow makeKeyAndVisible];

	if ([[CQChatController defaultController] hasPendingChatController])
		[[CQChatController defaultController] showPendingChatControllerAnimated:NO];

	[self handleNotificationWithUserInfo:launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey]];

	[self performSelector:@selector(performDeferredLaunchWork) withObject:nil afterDelay:1.];

	return YES;
}

- (void) applicationWillEnterForeground:(UIApplication *) application {
	[self cancelAllLocalNotifications];
}

- (void) applicationWillResignActive:(UIApplication *) application {
	_oldSwipeOrientationValue = [[CQSettingsController settingsController] objectForKey:@"CQSplitSwipeOrientations"];
}

- (void) application:(UIApplication *) application didReceiveLocalNotification:(UILocalNotification *) notification {
	[self handleNotificationWithUserInfo:notification.userInfo];
}

- (void) application:(UIApplication *) application didReceiveRemoteNotification:(NSDictionary *) userInfo {
	NSDictionary *apsInfo = userInfo[@"aps"];
	if (!apsInfo.count)
		return;

	self.applicationIconBadgeNumber = [apsInfo[@"badge"] integerValue];
}

- (void) application:(UIApplication *) application didRegisterUserNotificationSettings:(UIUserNotificationSettings *) notificationSettings {
	[self registerForRemoteNotifications];
}

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

- (BOOL) application:(UIApplication *) application handleOpenURL:(NSURL *) url {
	if ([url.scheme isCaseInsensitiveEqualToString:@"colloquy"]) {
		[[NSNotificationCenter chatCenter] postNotificationName:@"CQPocketShouldConvertTokenFromTokenNotification" object:nil];

		return YES;
	}

	return [[CQConnectionsController defaultController] handleOpenURL:url];
}

- (void) applicationWillTerminate:(UIApplication *) application {
	[UIApplication sharedApplication].applicationIconBadgeNumber = 0;

	self.appIconOptions = CQAppIconOptionConnect;

	[self submitRunTime];
}

#pragma mark -

- (void) showActionSheet:(UIActionSheet *) sheet {
	[self showActionSheet:sheet forSender:nil animated:YES];
}

- (void) showActionSheet:(UIActionSheet *) sheet fromPoint:(CGPoint) point {
	[self showActionSheet:sheet forSender:nil orFromPoint:point animated:YES];
}

- (void) showActionSheet:(UIActionSheet *) sheet forSender:(__nullable id) sender animated:(BOOL) animated {
	[self showActionSheet:sheet forSender:sender orFromPoint:CGPointZero animated:animated];
}

- (void) showActionSheet:(UIActionSheet *) sheet forSender:(__nullable id) sender orFromPoint:(CGPoint) point animated:(BOOL) animated {
	[_overlappingPresentationViewController.view removeFromSuperview];
	_overlappingPresentationViewController = nil;
	[_alertController dismissViewControllerAnimated:NO completion:nil];
	_alertController = nil;

	_alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
	if ([_alertController.popoverPresentationController respondsToSelector:@selector(canOverlapSourceViewRect)])
		_alertController.popoverPresentationController.canOverlapSourceViewRect = YES;

	// The overlapping view is needed to work around the following iOS 8(.1-only?) bug on iPad:
	// • If the root Split View Controller is configured to allow the main view overlap its detail views and we
	// present an action sheet from a point on screen that results in the popover rect overlapping the main view,
	// the z-index will be incorrect and the action sheet will be clipped by the main view.
	_overlappingPresentationViewController = [[UIViewController alloc] init];
	_overlappingPresentationViewController.view.backgroundColor = [UIColor clearColor];

	if ([sender isKindOfClass:[UIView class]] && [UIDevice currentDevice].isPadModel && !_mainWindow.isFullscreen) {
		_overlappingPresentationViewController.view.frame = [sender bounds];

		[sender addSubview:_overlappingPresentationViewController.view];

		_alertController.popoverPresentationController.sourceRect = [sender bounds];
		_alertController.popoverPresentationController.sourceView = sender;
	} else {
		_overlappingPresentationViewController.view.frame = _mainWindow.frame;

		[_mainWindow addSubview:_overlappingPresentationViewController.view];

		CGRect rect = CGRectZero;
		rect.size = CGSizeMake(1., 1.);
		rect.origin = CGPointEqualToPoint(point, CGPointZero) ? _mainWindow.center : point;

		_alertController.popoverPresentationController.sourceRect = rect;
		_alertController.popoverPresentationController.sourceView = _overlappingPresentationViewController.view;
	}

	for (NSInteger i = 0; i < sheet.numberOfButtons; i++) {
		NSString *title = [sheet buttonTitleAtIndex:i];
		UIAlertActionStyle style = UIAlertActionStyleDefault;
		if (i == sheet.cancelButtonIndex) style = UIAlertActionStyleCancel;
		else if (i == sheet.destructiveButtonIndex) style = UIAlertActionStyleDestructive;

		__weak __typeof__((self)) weakSelf = self;

		[_alertController addAction:[UIAlertAction actionWithTitle:title style:style handler:^(UIAlertAction *action) {
			__strong __typeof__((weakSelf)) strongSelf = weakSelf;

			[strongSelf->_alertController removeFromParentViewController];
			[strongSelf->_overlappingPresentationViewController.view removeFromSuperview];
			strongSelf->_alertController = nil;
			strongSelf->_overlappingPresentationViewController = nil;

			[sheet.delegate actionSheet:sheet clickedButtonAtIndex:i];
		}]];
	}

	[_overlappingPresentationViewController presentViewController:_alertController animated:YES completion:nil];
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

		[self reloadSplitViewController];
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
		return nil;
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
	return nil;
}

- (BOOL) openURL:(NSURL *) url {
	return [self openURL:url promptForExternal:YES];
}

- (BOOL) openURL:(NSURL *) url promptForExternal:(BOOL) prompt {
	if ([[CQConnectionsController defaultController] handleOpenURL:url])
		return YES;

	if (url && ![self canOpenURL:url])
		return NO;

	if ([self isSpecialApplicationURL:url]) {
		if (!prompt)
			return [super openURL:url];

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
	} else [super openURL:url];

	return YES;
}

#pragma mark -

- (void) alertView:(UIAlertView *) alertView clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (alertView.tag != BrowserAlertTag || alertView.cancelButtonIndex == buttonIndex)
		return;
	[super openURL:[alertView associatedObjectForKey:@"userInfo"]];
}

#pragma mark -

- (UIColor *) tintColor {
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

- (void) updateAppShortcuts {
	CQAppIconOptions options = CQAppIconOptionNone;

	if ([CQConnectionsController defaultController].connectedConnections.count)
		options |= CQAppIconOptionDisconnect;
	if ([CQConnectionsController defaultController].connectedConnections.count != [CQConnectionsController defaultController].connections.count)
		options |= CQAppIconOptionConnect;
	if ([CQChatController defaultController].totalImportantUnreadCount || [CQChatController defaultController].totalUnreadCount)
		options |= CQAppIconOptionMarkAllAsRead;

	self.appIconOptions = options;
}

- (void) setAppIconOptions:(CQAppIconOptions) appIconOptions {
	if (![self respondsToSelector:@selector(setShortcutItems:)])
		return;

	_appIconOptions = appIconOptions;

	NSMutableArray *options = [NSMutableArray array];
	if ((appIconOptions & CQAppIconOptionConnect) == CQAppIconOptionConnect)
		[options addObject:[[UIMutableApplicationShortcutItem alloc] initWithType:@"CQAppShortcutConnect" localizedTitle:NSLocalizedString(@"Connect", @"Connect")]];

	if ((appIconOptions & CQAppIconOptionDisconnect) == CQAppIconOptionDisconnect)
		[options addObject:[[UIMutableApplicationShortcutItem alloc] initWithType:@"CQAppShortcutDisconnect" localizedTitle:NSLocalizedString(@"Disconnect", @"Disconnect")]];

	if ((appIconOptions & CQAppIconOptionMarkAllAsRead) == CQAppIconOptionMarkAllAsRead)
		[options addObject:[[UIMutableApplicationShortcutItem alloc] initWithType:@"CQAppShortcutMarkAsRead" localizedTitle:NSLocalizedString(@"Mark Messages As Read", @"Mark Messages As Read")]];

	self.shortcutItems = options;
}

- (void) application:(UIApplication *) application performActionForShortcutItem:(UIApplicationShortcutItem *) shortcutItem completionHandler:(void(^)(BOOL succeeded)) completionHandler {
	if ([shortcutItem.type isEqualToString:@"CQAppShortcutConnect"])
		[[CQConnectionsController defaultController] openAllConnections];
	else if ([shortcutItem.type isEqualToString:@"CQAppShortcutDisconnect"])
		[[CQConnectionsController defaultController] closeAllConnections];
	else if ([shortcutItem.type isEqualToString:@"CQAppShortcutMarkAsread"])
		[[CQChatController defaultController] resetTotalUnreadCount];
}

#pragma mark -

- (UIUserNotificationType) enabledNotificationTypes {
	return self.currentUserNotificationSettings.types;
}

- (void) registerForNotificationTypes:(UIUserNotificationType) types {
	[self registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:types categories:nil]];
}

- (BOOL) areNotificationBadgesAllowed {
	return (_deviceToken || [self enabledNotificationTypes] & UIUserNotificationTypeBadge);
}

- (BOOL) areNotificationSoundsAllowed {
	return (_deviceToken || [self enabledNotificationTypes] & UIUserNotificationTypeSound);
}

- (BOOL) areNotificationAlertsAllowed {
	return (_deviceToken || [self enabledNotificationTypes] & UIUserNotificationTypeAlert);
}

- (void) setApplicationIconBadgeNumber:(NSInteger) applicationIconBadgeNumber {
	if (self.areNotificationBadgesAllowed)
		[super setApplicationIconBadgeNumber:applicationIconBadgeNumber];
}

- (void) presentLocalNotificationNow:(UILocalNotification *) notification {
	if (![self areNotificationAlertsAllowed])
		notification.alertBody = nil;
	if (![self areNotificationSoundsAllowed])
		notification.soundName = nil;
	if (![self areNotificationBadgesAllowed])
		notification.applicationIconBadgeNumber = 0;

	if (notification.alertBody.length || notification.soundName.length || notification.applicationIconBadgeNumber > 0)
		[super presentLocalNotificationNow:notification];
}

- (void) registerForPushNotifications {
#if !TARGET_IPHONE_SIMULATOR
	static BOOL registeredForPush;
	if (!registeredForPush) {
		[self registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
		registeredForPush = YES;
	}
#endif
}
@end

NS_ASSUME_NONNULL_END
