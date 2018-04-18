#import "CQDirectChatController.h"

#import "CQActivities.h"
#import "CQBookmarkingController.h"
#import "CQChatOrderingController.h"
#import "CQChatCreationViewController.h"
#import "CQChatInputBar.h"
#import "CQChatInputStyleViewController.h"
#import "CQChatPresentationController.h"
#import "CQChatRoomController.h"
#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"
#import "CQGiphyController.h"
#import "CQIgnoreRulesController.h"
#import "CQImportantChatMessageViewController.h"
#import "CQProcessChatMessageOperation.h"
#import "CQSoundController.h"
#import "CQUserInfoController.h"
#import "KAIgnoreRule.h"
#import "NSAttributedStringAdditions.h"
#import "NSDateAdditions.h"
#import "NSNotificationAdditions.h"
#import "UIViewAdditions.h"
#import "CQUIChatTranscriptView.h"
#import "CQUITextChatTranscriptView.h"
#import "CQWKChatTranscriptView.h"

#import <ChatCore/MVChatUser.h>
#import <ChatCore/MVChatUserWatchRule.h>

#if !SYSTEM(TV)
#import <MediaPlayer/MPMusicPlayerController.h>
#import <Social/Social.h>
#import <UserNotifications/UserNotifications.h>
#endif

#import <objc/message.h>

#define InfoActionSheet 1001
#define URLActionSheet 1003

typedef NS_ENUM(NSInteger, CQSwipeMeaning) {
	CQSwipeDisabled,
	CQSwipeNextRoom,
	CQSwipeNextActiveRoom,
	CQSwipeNextHighlight
};

NSString *CQChatViewControllerHandledMessageNotification = @"CQChatViewControllerHandledMessageNotification";
NSString *CQChatViewControllerRecentMessagesUpdatedNotification = @"CQChatViewControllerRecentMessagesUpdatedNotification";
NSString *CQChatViewControllerUnreadMessagesUpdatedNotification = @"CQChatViewControllerUnreadMessagesUpdatedNotification";

static NSString *CQScrollbackLengthDidChangeNotification = @"CQScrollbackLengthDidChangeNotification";

static CQSoundController *privateMessageSound;
static CQSoundController *highlightSound;
static BOOL timestampEveryMessage;
static NSString *timestampFormat;
static NSTimeInterval timestampInterval;
static BOOL timestampOnLeft;
static NSTimeInterval privateMessageAlertTimeout;
static BOOL graphicalEmoticons;
static BOOL naturalChatActions;
static BOOL vibrateOnHighlight;
static BOOL vibrateOnPrivateMessage;
static BOOL localNotificationOnHighlight;
static BOOL localNotificationOnPrivateMessage;
static NSUInteger scrollbackLength;
static BOOL clearOnConnect;
static BOOL markScrollbackOnMultitasking;
static NSUInteger singleSwipeGesture;
static NSUInteger doubleSwipeGesture;
static NSUInteger tripleSwipeGesture;
static BOOL historyOnReconnect;

#pragma mark -

static NSOperationQueue *chatMessageProcessingQueue;
static BOOL hardwareKeyboard;
static BOOL showingKeyboard;

#pragma mark -

NS_ASSUME_NONNULL_BEGIN

@interface CQDirectChatController () <CQChatInputBarDelegate, CQChatTranscriptViewDelegate, CQImportantChatMessageDelegate, CQActionSheetDelegate, CQChatInputStyleDelegate>
@property (strong, nullable) UIActivityViewController *activityController;
@end

@implementation CQDirectChatController {
	BOOL _showingActivityViewController;
}

+ (void) userDefaultsChanged {
	if (![NSThread isMainThread])
		return;

	timestampFormat = [[CQSettingsController settingsController] objectForKey:@"CQTimestampFormat"];
	timestampFormat = [NSDateFormatter dateFormatFromTemplate:timestampFormat options:0 locale:[NSLocale currentLocale]];
	timestampInterval = [[CQSettingsController settingsController] doubleForKey:@"CQTimestampInterval"];
	timestampEveryMessage = (timestampInterval == -1);
	timestampOnLeft = [[CQSettingsController settingsController] boolForKey:@"CQTimestampOnLeft"];

	privateMessageAlertTimeout = [[CQSettingsController settingsController] doubleForKey:@"CQPrivateMessageAlertTimeout"];
	graphicalEmoticons = [[CQSettingsController settingsController] boolForKey:@"CQGraphicalEmoticons"];
	naturalChatActions = [[CQSettingsController settingsController] boolForKey:@"MVChatNaturalActions"];
	vibrateOnHighlight = [[CQSettingsController settingsController] boolForKey:@"CQVibrateOnHighlight"];
	vibrateOnPrivateMessage = [[CQSettingsController settingsController] boolForKey:@"CQVibrateOnPrivateMessage"];
	localNotificationOnHighlight = [[CQSettingsController settingsController] boolForKey:@"CQShowLocalNotificationOnHighlight"];
	localNotificationOnPrivateMessage = [[CQSettingsController settingsController] boolForKey:@"CQShowLocalNotificationOnPrivateMessage"];
	clearOnConnect = [[CQSettingsController settingsController] boolForKey:@"CQClearOnConnect"];
	markScrollbackOnMultitasking = [[CQSettingsController settingsController] boolForKey:@"CQMarkScrollbackOnMultitasking"];
	singleSwipeGesture = [[CQSettingsController settingsController] integerForKey:@"CQSingleFingerSwipe"];
	doubleSwipeGesture = [[CQSettingsController settingsController] integerForKey:@"CQDoubleFingerSwipe"];
	tripleSwipeGesture = [[CQSettingsController settingsController] integerForKey:@"CQTripleFingerSwipe"];
	historyOnReconnect = [[CQSettingsController settingsController] boolForKey:@"CQHistoryOnReconnect"];

	NSUInteger newScrollbackLength = [[CQSettingsController settingsController] integerForKey:@"CQScrollbackLength"];
	if (newScrollbackLength != scrollbackLength) {
		scrollbackLength = newScrollbackLength;

		[[NSNotificationCenter chatCenter] postNotificationName:CQScrollbackLengthDidChangeNotification object:nil];
	}

	NSString *soundName = [[CQSettingsController settingsController] stringForKey:@"CQSoundOnPrivateMessage"];

	privateMessageSound = ([soundName isEqualToString:@"None"] ? nil : [[CQSoundController alloc] initWithSoundNamed:soundName]);
	soundName = [[CQSettingsController settingsController] stringForKey:@"CQSoundOnHighlight"];
	highlightSound = ([soundName isEqualToString:@"None"] ? nil : [[CQSoundController alloc] initWithSoundNamed:soundName]);
}

- (void) didNotBookmarkLink:(NSNotification *) notification {
	id <NSObject, CQBookmarking> activeService = [CQBookmarkingController activeService];

	NSError *error = notification.userInfo[@"error"];
	if (error.code == CQBookmarkingErrorAuthorization) {
		if ([activeService respondsToSelector:@selector(authorize)]) {
			[activeService authorize];
		} else {
			UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[activeService serviceName].capitalizedString message:@"" preferredStyle:UIAlertControllerStyleAlert];
			alertController.message = [NSString stringWithFormat:NSLocalizedString(@"Unable to save \"%@\" to %@ due to a server error.", @"Unable to bookmark link server error message"), notification.object, [activeService serviceName]];

			[alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
				textField.placeholder = NSLocalizedString(@"Username or Email", @"Username or Email placeholder");
			}];
			[alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
				textField.secureTextEntry = YES;
				textField.placeholder = NSLocalizedString(@"Password", @"Password placeholder");
			}];

			[alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
				_showingAlert = NO;
			}]];
			[alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Log In", @"Log In button") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
				_showingAlert = NO;
				[[CQBookmarkingController activeService] setUsername:alertController.textFields[0].text password:alertController.textFields[1].text];
				[[CQBookmarkingController activeService] bookmarkLink:notification.object];
			}]];

			_showingAlert = YES;
			[self presentViewController:alertController animated:YES completion:nil];
		}
	} else if (error.code == CQBookmarkingErrorServer) {
		UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:@"" preferredStyle:UIAlertControllerStyleAlert];
		alertController.title = NSLocalizedString(@"Server Error", @"Server Error");
		alertController.message = [NSString stringWithFormat:NSLocalizedString(@"Unable to save \"%@\" to %@ due to a server error.", @"Unable to bookmark link server error message"), notification.object, [activeService serviceName]];

		[alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Okay", @"Okay alert button title") style:UIAlertActionStyleDefault handler:nil]];

		[self presentViewController:alertController animated:YES completion:nil];
	} else {
		UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:@"" preferredStyle:UIAlertControllerStyleAlert];
		alertController.title = NSLocalizedString(@"Unknown Error", @"Unknown Error");
		alertController.message = [NSString stringWithFormat:NSLocalizedString(@"Unable to save \"%@\" to %@.", @"Unable to bookmark link message"), notification.object, [activeService serviceName]];

		[alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Okay", @"Okay alert button title") style:UIAlertActionStyleDefault handler:nil]];

		[self presentViewController:alertController animated:YES completion:nil];
	}
}

+ (void) initialize {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(userDefaultsChanged) name:CQSettingsDidChangeNotification object:nil];

		[self userDefaultsChanged];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow) name:UIKeyboardWillShowNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide) name:UIKeyboardWillHideNotification object:nil];
	});
}

+ (void) keyboardWillShow {
	showingKeyboard = YES;
}

+ (void) keyboardWillHide {
	showingKeyboard = NO;
}

+ (NSOperationQueue *) chatMessageProcessingQueue {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		chatMessageProcessingQueue = [[NSOperationQueue alloc] init];
		chatMessageProcessingQueue.maxConcurrentOperationCount = 1;
		chatMessageProcessingQueue.qualityOfService = NSQualityOfServiceUserInitiated;
	});

	return chatMessageProcessingQueue;
}

- (instancetype) initWithStyle:(UITableViewStyle) style {
	NSAssert(NO, @"use -[CQDirectChatController initWithTarget:] instead");
	return nil;
}

- (instancetype) initWithNibName:(NSString *__nullable) nibNameOrNil bundle:(NSBundle *__nullable) nibBundleOrNil {
	NSAssert(NO, @"use -[CQDirectChatController initWithTarget:] instead");
	return nil;
}

- (instancetype) initWithCoder:(NSCoder *) aDecoder {
	NSAssert(NO, @"use -[CQDirectChatController initWithTarget:] instead");
	return nil;
}

- (instancetype) initWithTarget:(__nullable id) target {
#if !SYSTEM(TV)
	if (!(self = [super initWithNibName:@"CQUIChatView" bundle:nil]))
		return nil;
#else
	if (!(self = [super initWithNibName:nil bundle:nil]))
#endif

	_target = target;

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_awayStatusChanged:) name:MVChatConnectionSelfAwayStatusChangedNotification object:self.connection];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_willConnect:) name:MVChatConnectionWillConnectNotification object:self.connection];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_didConnect:) name:MVChatConnectionDidConnectNotification object:self.connection];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_didDisconnect:) name:MVChatConnectionDidDisconnectNotification object:self.connection];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_didRecieveDeviceToken:) name:CQColloquyApplicationDidRecieveDeviceTokenNotification object:nil];

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_userDefaultsChanged) name:CQSettingsDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_userDefaultsChanged) name:UIContentSizeCategoryDidChangeNotification object:nil];

	_showingKeyboard = showingKeyboard;

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_nicknameDidChange:) name:MVChatUserNicknameChangedNotification object:nil];

	if (self.user) {
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_userNicknameDidChange:) name:MVChatUserNicknameChangedNotification object:self.user];

		_encoding = [[CQSettingsController settingsController] integerForKey:@"CQDirectChatEncoding"];

		_watchRule = [[MVChatUserWatchRule alloc] init];
		_watchRule.nickname = self.user.nickname;

		[self.connection addChatUserWatchRule:_watchRule];

		_showingKeyboard = YES;
	}

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(scrollbackLengthDidChange:) name:CQScrollbackLengthDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_willTerminate) name:UIApplicationWillTerminateNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_resignActive) name:UIApplicationWillResignActiveNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_batchUpdatesWillBegin:) name:MVChatConnectionBatchUpdatesWillBeginNotification object:nil];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_batchUpdatesDidEnd:) name:MVChatConnectionBatchUpdatesDidEndNotification object:nil];

	[self setScrollbackLength:scrollbackLength];

	_sentMessages = [[NSMutableArray alloc] init];
	_batchTypeAssociation = [NSMutableDictionary dictionary];

	return self;
}

- (instancetype) initWithPersistentState:(NSDictionary *) state usingConnection:(MVChatConnection *) connection {
	MVChatUser *user = nil;

	NSString *nickname = state[@"user"];
	if (!nickname) {
		return nil;
	}

	user = [connection chatUserWithUniqueIdentifier:nickname];
	if (!user) {
		return nil;
	}

	if (!(self = [self initWithTarget:user]))
		return nil;

	[self restorePersistentState:state usingConnection:connection];

	return self;
}

- (void) restorePersistentState:(NSDictionary *) state usingConnection:(MVChatConnection *) connection {
	_active = [state[@"active"] boolValue];

	if (historyOnReconnect) {
		_pendingPreviousSessionComponents = [[NSMutableArray alloc] init];

		for (NSDictionary *message in state[@"messages"]) {
			NSMutableDictionary *messageCopy = [message mutableCopy];

			MVChatUser *user = nil;
			if ([messageCopy[@"localUser"] boolValue]) {
				user = connection.localUser;
				[messageCopy removeObjectForKey:@"localUser"];
			} else user = [connection chatUserWithUniqueIdentifier:messageCopy[@"user"]];

			if (user) {
				messageCopy[@"user"] = user;

				[_pendingPreviousSessionComponents addObject:messageCopy];
			}
		}

		_recentMessages = [_pendingPreviousSessionComponents mutableCopy];

		while (_recentMessages.count > 10)
			[_recentMessages removeObjectAtIndex:0];
	} else {
		_recentMessages = [[NSMutableArray alloc] init];
	}
}

- (void) dealloc {
	[[NSNotificationCenter chatCenter] removeObserver:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	if (_watchRule)
		[self.connection removeChatUserWatchRule:_watchRule];
}

#pragma mark -

- (id) target {
	return _target;
}

- (MVChatUser *) user {
	return (MVChatUser *)_target;
}

#pragma mark -

- (UIImage *) icon {
	static UIImage *icon = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		icon = [UIImage imageNamed:@"directChatIcon.png"];
	});
	return icon;
}

- (void) setTitle:(NSString *__nullable) title {
	// Do nothing, not changeable.
}

- (NSString *) title {
	return self.user.displayName;
}

- (MVChatConnection *) connection {
	return self.user.connection;
}

- (BOOL) available {
	MVChatUserStatus status = self.user.status;
	return (self.connection.connected && (status == MVChatUserAvailableStatus || status == MVChatUserAwayStatus));
}

- (NSStringEncoding) encoding {
	return (_encoding ? _encoding : self.connection.encoding);
}

- (NSDictionary *) persistentState {
	if (!_target)
		return @{};

	NSMutableDictionary *state = [[NSMutableDictionary alloc] init];

	state[@"class"] = NSStringFromClass([self class]);

	if ([CQChatController defaultController].visibleChatController == self)
		state[@"active"] = @(YES);

	if (self.user)
		state[@"user"] = self.user.nickname;

	NSMutableArray *messages = [[NSMutableArray alloc] init];

	for (NSDictionary *message in _recentMessages) {
		static NSArray <NSString *> *sameKeys = nil;
		if (!sameKeys)
			sameKeys = @[@"message", @"messagePlain", @"action", @"notice", @"highlighted", @"identifier", @"type"];

		NSMutableDictionary *newMessage = [[NSMutableDictionary alloc] initWithKeys:sameKeys fromDictionary:message];

		if ([newMessage[@"message"] isEqual:newMessage[@"messagePlain"]])
			[newMessage removeObjectForKey:@"messagePlain"];

		MVChatUser *user = message[@"user"];
		if (user && !user.localUser) newMessage[@"user"] = user.nickname;
		else if (user.localUser) newMessage[@"localUser"] = @(YES);

		[messages addObject:newMessage];
	}

	if (messages.count)
		state[@"messages"] = messages;

	return state;
}

#pragma mark -

- (CQActionSheet *) actionSheet {
	CQActionSheet *sheet = [[CQActionSheet alloc] init];
	sheet.delegate = self;
	sheet.tag = InfoActionSheet;

#if !SYSTEM(TV)
	if (self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassRegular && self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular)
		sheet.title = self.user.displayName;
#endif

	[sheet addButtonWithTitle:NSLocalizedString(@"User Information", @"User Information button title")];

	sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	return sheet;
}

#pragma mark -

- (NSUInteger) unreadCount {
	return _unreadMessages;
}

- (NSUInteger) importantUnreadCount {
	return _unreadHighlightedMessages;
}

#pragma mark -

- (void) style:(__nullable id) sender {
	_styleViewController = [[CQChatInputStyleViewController alloc] init];
	_styleViewController.delegate = self;

	CQModalNavigationController *navigationController = [[CQModalNavigationController alloc] initWithRootViewController:_styleViewController];
	navigationController.closeButtonItem = UIBarButtonSystemItemDone;

	[[CQColloquyApplication sharedApplication] presentModalViewController:navigationController animated:YES];

	[self _updateAttributesForStyleViewController];
}

#pragma mark -

- (void) saveChatLog:(id) sender {
	NSData *transcriptPDF = transcriptView.PDFRepresentation;
	if (!transcriptPDF)
		return;

	[self _showActivityViewControllerWithItems:@[ transcriptPDF ] activities:@[]];
}

- (void) showRecentlySentMessages:(id) sender {
	CQImportantChatMessageViewController *listViewController = [[CQImportantChatMessageViewController alloc] initWithMessages:_sentMessages delegate:self];
	CQModalNavigationController *modalNavigationController = [[CQModalNavigationController alloc] initWithRootViewController:listViewController];

	[[CQColloquyApplication sharedApplication] presentModalViewController:modalNavigationController animated:[UIView areAnimationsEnabled]];
}

- (void) showUserInformation {
	if (!self.user)
		return;

	[self _showUserInfoControllerForUser:self.user];
}

#pragma mark -

- (NSArray <UIKeyCommand *> *__nullable) keyCommands {
	static NSArray <UIKeyCommand *> *keyCommands = nil;
	if (!keyCommands) {
		UIKeyCommand *altTabKeyCommand = [UIKeyCommand keyCommandWithInput:@"\t" modifierFlags:UIKeyModifierAlternate action:@selector(_handleKeyCommand:)];
		UIKeyCommand *shiftAltTabKeyCommand = [UIKeyCommand keyCommandWithInput:@"\t" modifierFlags:(UIKeyModifierAlternate | UIKeyModifierShift) action:@selector(_handleKeyCommand:)];
		UIKeyCommand *cmdUpKeyCommand = [UIKeyCommand keyCommandWithInput:UIKeyInputUpArrow modifierFlags:UIKeyModifierCommand action:@selector(_handleKeyCommand:)];
		UIKeyCommand *cmdDownKeyCommand = [UIKeyCommand keyCommandWithInput:UIKeyInputDownArrow modifierFlags:UIKeyModifierCommand action:@selector(_handleKeyCommand:)];
		UIKeyCommand *optCmdUpKeyCommand = [UIKeyCommand keyCommandWithInput:UIKeyInputUpArrow modifierFlags:(UIKeyModifierCommand | UIKeyModifierAlternate) action:@selector(_handleKeyCommand:)];
		UIKeyCommand *optCmdDownKeyCommand = [UIKeyCommand keyCommandWithInput:UIKeyInputDownArrow modifierFlags:(UIKeyModifierCommand | UIKeyModifierAlternate) action:@selector(_handleKeyCommand:)];

		UIKeyCommand *cmdShiftCKeyCommand = [UIKeyCommand keyCommandWithInput:@"c" modifierFlags:(UIKeyModifierCommand | UIKeyModifierShift) action:@selector(_handleKeyCommand:)];
		UIKeyCommand *cmdShiftKKeyCommand = [UIKeyCommand keyCommandWithInput:@"k" modifierFlags:(UIKeyModifierCommand | UIKeyModifierShift) action:@selector(_handleKeyCommand:)];
		UIKeyCommand *cmdShiftNKeyCommand = [UIKeyCommand keyCommandWithInput:@"n" modifierFlags:(UIKeyModifierCommand | UIKeyModifierShift) action:@selector(_handleKeyCommand:)];
		UIKeyCommand *cmdNKeyCommand = [UIKeyCommand keyCommandWithInput:@"n" modifierFlags:(UIKeyModifierCommand) action:@selector(_handleKeyCommand:)];
		UIKeyCommand *cmdJKeyCommand = [UIKeyCommand keyCommandWithInput:@"j" modifierFlags:(UIKeyModifierCommand) action:@selector(_handleKeyCommand:)];
		UIKeyCommand *escCommand = [UIKeyCommand keyCommandWithInput:UIKeyInputEscape modifierFlags:0 action:@selector(_handleKeyCommand:)];

		if ([UIKeyCommand instancesRespondToSelector:@selector(setDiscoverabilityTitle:)]) {
			NSString *nextRoomTitle = NSLocalizedString(@"Next Chat Room", @"Next Chat Room discoverability HUD title");
			NSArray *nextRoomCommands = @[ altTabKeyCommand, cmdUpKeyCommand, optCmdUpKeyCommand ];
			[nextRoomCommands makeObjectsPerformSelector:@selector(setDiscoverabilityTitle:) withObject:nextRoomTitle];

			NSString *previousRoomTitle = NSLocalizedString(@"Previous Chat Room", @"Previous Chat Room discoverability HUD title");
			NSArray *previousRoomCommands = @[ shiftAltTabKeyCommand, cmdDownKeyCommand, optCmdDownKeyCommand ];
			[previousRoomCommands makeObjectsPerformSelector:@selector(setDiscoverabilityTitle:) withObject:previousRoomTitle];

			cmdShiftCKeyCommand.discoverabilityTitle = NSLocalizedString(@"Style Message", @"Style Message discoverability HUD title");
			cmdShiftKKeyCommand.discoverabilityTitle = NSLocalizedString(@"Clear Message", @"Clear Message discoverability HUD title");
			cmdShiftNKeyCommand.discoverabilityTitle = NSLocalizedString(@"New Connection", @"New Connection discoverability HUD title");
			cmdJKeyCommand.discoverabilityTitle = NSLocalizedString(@"New Colloquy", @"New Colloquy discoverability HUD title");
			cmdNKeyCommand.discoverabilityTitle = NSLocalizedString(@"New Colloquy", @"New Colloquy discoverability HUD title");
			escCommand.discoverabilityTitle = NSLocalizedString(@"Dismiss Topmost View", @"Dismiss Topmost View discoverability HUD title");
		}

		keyCommands = @[ altTabKeyCommand, shiftAltTabKeyCommand, cmdUpKeyCommand, cmdDownKeyCommand, optCmdUpKeyCommand, optCmdDownKeyCommand,
						 cmdShiftCKeyCommand, cmdNKeyCommand, cmdShiftKKeyCommand, cmdJKeyCommand, cmdShiftNKeyCommand, escCommand ];
	}

	return keyCommands;
}

- (UIScrollView *) scrollView {
	return transcriptView.scrollView;
}

#pragma mark -

- (UIViewController *) previewableViewController {
	UIViewController *viewController = [[UIViewController alloc] init];
	if (![self isViewLoaded]) {
		[self loadViewIfNeeded];

		while (!transcriptView.readyForDisplay)
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:CQWebViewMagicNumber]];
	}

	viewController.view = [transcriptView snapshotViewAfterScreenUpdates:YES];
	return viewController;
}

#pragma mark -

- (void) loadView {
	[super loadView];

//	// while CQWKChatView exists and is ready to be used (for the most part), WKWebView does not support being loaded from a xib yet
#if SYSTEM(TV)
	CQUITextChatTranscriptView *chatTranscriptView = [[CQUITextChatTranscriptView alloc] initWithFrame:transcriptView.frame];
#elif 0
	CQWKChatTranscriptView *chatTranscriptView = [[CQWKChatTranscriptView alloc] initWithFrame:transcriptView.frame];
#else
	// if we want to keep using UIWebView-based transcripts, don't set the var to anything so it never gets removed
	CQUIChatTranscriptView *chatTranscriptView = nil;
#endif
	chatTranscriptView.autoresizingMask = transcriptView.autoresizingMask;
	chatTranscriptView.transcriptDelegate = self;

	if (chatTranscriptView) {
		[transcriptView.superview insertSubview:chatTranscriptView aboveSubview:transcriptView];

		[transcriptView removeFromSuperview];
		transcriptView = chatTranscriptView;
	}
}

- (void) viewDidLoad {
	[super viewDidLoad];

	[self _updateRightBarButtonItemAnimated:NO];

	chatInputBar.accessibilityLabel = NSLocalizedString(@"Enter chat message.", @"Voiceover enter chat message label");
	chatInputBar.accessibilityTraits = UIAccessibilityTraitUpdatesFrequently;

	[self _userDefaultsChanged];

	transcriptView.allowSingleSwipeGesture = (![[UIDevice currentDevice] isPadModel] && !(self.splitViewController.displayMode == UISplitViewControllerDisplayModePrimaryHidden || self.splitViewController.displayMode == UISplitViewControllerDisplayModePrimaryOverlay));
	[chatInputBar setAccessoryImage:[UIImage imageNamed:@"clear.png"] forResponderState:CQChatInputBarResponder controlState:UIControlStateNormal];
	[chatInputBar setAccessoryImage:[UIImage imageNamed:@"clearPressed.png"] forResponderState:CQChatInputBarResponder controlState:UIControlStateHighlighted];
	[chatInputBar setAccessoryImage:[UIImage imageNamed:@"infoButton.png"] forResponderState:CQChatInputBarNotResponder controlState:UIControlStateNormal];
	[chatInputBar setAccessoryImage:[UIImage imageNamed:@"infoButtonPressed.png"] forResponderState:CQChatInputBarNotResponder controlState:UIControlStateHighlighted];

	[chatInputBar setAccessibilityLabel:NSLocalizedString(@"User Controls", @"Info Accessibility Label") forResponderState:CQChatInputBarNotResponder];
	[chatInputBar setAccessibilityLabel:NSLocalizedString(@"Clear Text", @"Clear Text Accessibility Label") forResponderState:CQChatInputBarResponder];
}

- (void) viewWillAppear:(BOOL) animated {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

	if (_showingKeyboard || showingKeyboard || hardwareKeyboard)
		[chatInputBar becomeFirstResponder];

	[super viewWillAppear:animated];

	[self _addPendingComponentsAnimated:NO];

	if (self.connection.connected)
		[_target setMostRecentUserActivity:[NSDate date]];

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(didNotBookmarkLink:) name:CQBookmarkingDidNotSaveLinkNotification object:nil];

	if ([transcriptView.styleIdentifier hasCaseInsensitiveSuffix:@"-dark"])
		self.navigationController.navigationBar.barTintColor = [[UIColor darkGrayColor] colorWithAlphaComponent:.9];
}

- (void) viewDidAppear:(BOOL) animated {
	[super viewDidAppear:animated];

	_active = YES;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_willEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_willBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];

	[self _addPendingComponentsAnimated:YES];

	[transcriptView performSelector:@selector(flashScrollIndicators) withObject:nil afterDelay:0.1];

	[self markAsRead];

	[[NSNotificationCenter chatCenter] postNotificationName:CQChatViewControllerUnreadMessagesUpdatedNotification object:self];
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	if (self.connection.connected)
		[_target setMostRecentUserActivity:[NSDate date]];

	hardwareKeyboard = (!_showingKeyboard && [chatInputBar isFirstResponder]);
	[chatInputBar resignFirstResponder];

	[chatInputBar hideCompletions];

	_active = NO;
	_allowEditingToEnd = YES;

	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];

	[[NSNotificationCenter chatCenter] removeObserver:self name:CQBookmarkingDidNotSaveLinkNotification object:nil];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];

	if (!self.view.window.isFullscreen)
		[self.view endEditing:YES];

	[super viewWillDisappear:animated];
}

- (void) viewDidDisappear:(BOOL) animated {
	[super viewDidDisappear:animated];

#if !SYSTEM(TV)
	[UIMenuController sharedMenuController].menuItems = nil;
#endif

	if (!self.view.window.isFullscreen)
		[chatInputBar resignFirstResponder];

	_allowEditingToEnd = NO;
}

- (void) viewWillLayoutSubviews {
	[super viewWillLayoutSubviews];

	[chatInputBar updateTextViewContentSize];
}

- (void) viewWillTransitionToSize:(CGSize) size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>) coordinator {
	BOOL isShowingCompletionsBeforeRotation = chatInputBar.isShowingCompletions;

	[coordinator animateAlongsideTransition:nil completion:^(id <UIViewControllerTransitionCoordinatorContext> context) {
		[transcriptView scrollToBottomAnimated:NO];

		if (isShowingCompletionsBeforeRotation)
			[self _showChatCompletions];

		transcriptView.allowSingleSwipeGesture = (![[UIDevice currentDevice] isPadModel] && !(self.splitViewController.displayMode == UISplitViewControllerDisplayModePrimaryHidden || self.splitViewController.displayMode == UISplitViewControllerDisplayModePrimaryOverlay));
	}];
}

- (BOOL) canBecomeFirstResponder {
	return YES;
}

- (BOOL) becomeFirstResponder {
	if (_showingActivityViewController)
		return [super becomeFirstResponder];
	return NO;
}

- (BOOL) isFirstResponder {
	return [chatInputBar isFirstResponder];
}

- (BOOL) resignFirstResponder {
	if (_showingActivityViewController)
		return [super resignFirstResponder];
	return [chatInputBar resignFirstResponder];
}

- (void)traitCollectionDidChange:(UITraitCollection *__nullable)previousTraitCollection {
	[super traitCollectionDidChange:previousTraitCollection];
	[self _userDefaultsChanged];
}

#pragma mark -

- (void) chatInputBarTextDidChange:(CQChatInputBar *) theChatInputBar {
#if !SYSTEM(TV)
	if (chatInputBar.textView.text.length || chatInputBar.textView.attributedText.length) {
		chatInputBar.textView.allowsEditingTextAttributes = YES;
		[UIMenuController sharedMenuController].menuItems = @[ [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Style", @"Style text menu item") action:@selector(style:)] ];
	} else {
		chatInputBar.textView.allowsEditingTextAttributes = NO;
		[UIMenuController sharedMenuController].menuItems = nil;
	}
#endif
}

- (void) chatInputBarAccessoryButtonPressed:(CQChatInputBar *) theChatInputBar {
	if ([theChatInputBar isFirstResponder] && theChatInputBar.textView.hasText) {
		theChatInputBar.textView.text = nil;

		// Work around behavior where textViewDidChange: isn't called when you change the text programatically.
		__strong id <UITextViewDelegate> strongDelegate = theChatInputBar.textView.delegate;
		if ([strongDelegate respondsToSelector:@selector(textViewDidChange:)])
			[strongDelegate textViewDidChange:theChatInputBar.textView];

		[theChatInputBar hideCompletions];

		return;
	}

	[self _showActivityViewControllerWithItems:@[] activities:[CQActivitiesProvider activities]];
}

- (BOOL) chatInputBarShouldEndEditing:(CQChatInputBar *) chatInputBar {
	if (_showingAlert)
		return NO;

	if (_allowEditingToEnd)
		return YES;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkTranscriptViewForBecomeFirstResponder) object:nil];
	[self performSelector:@selector(checkTranscriptViewForBecomeFirstResponder) withObject:nil afterDelay:0.4];

	return NO;
}

- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar shouldAutocorrectWordWithPrefix:(NSString *) word {
	if ([word hasPrefix:@"/"] || [word hasPrefix:@"#"] || [word hasCaseInsensitiveSubstring:@"://"] || [word hasCaseInsensitiveSubstring:@"www."])
		return NO;

	if (word.length > 1 && word.length <= 5) {
		static NSSet *knownEmoticonsSet;
		if (!knownEmoticonsSet)
			knownEmoticonsSet = [[NSSet alloc] initWithArray:[NSString knownEmoticons]];
		if ([knownEmoticonsSet containsObject:word])
			return NO;
	}

	return YES;
}

- (NSArray <NSString *> *) chatInputBar:(CQChatInputBar *) chatInputBar completionsForWordWithPrefix:(NSString *) word inRange:(NSRange) range {
	NSMutableArray *completions = [[NSMutableArray alloc] init];

	if (word.length >= 2) {
		NSString *nickname = (range.location ? self.user.nickname : [self.user.nickname stringByAppendingString:@":"]);
		if ([nickname hasCaseInsensitivePrefix:word] && ![nickname isEqualToString:word])
			[completions addObject:nickname];

		nickname = (range.location ? self.connection.nickname : [self.connection.nickname stringByAppendingString:@":"]);
		if ([nickname hasCaseInsensitivePrefix:word] && ![nickname isEqualToString:word])
			[completions addObject:nickname];

		static NSArray <NSString *> *services;
		if (!services) services = @[@"NickServ", @"ChanServ", @"MemoServ", @"OperServ"];

		for (NSString *service in services) {
			if ([service hasCaseInsensitivePrefix:word] && ![service isCaseInsensitiveEqualToString:word])
				[completions addObject:service];
		}

		for (MVChatRoom *room in self.connection.knownChatRooms) {
			if ([room.name hasCaseInsensitivePrefix:word] && ![room.name isCaseInsensitiveEqualToString:word])
				[completions addObject:room.name];
			if (completions.count >= 10)
				break;
		}
	}

	if ([word hasPrefix:@"/"]) {
		static NSArray <NSString *> *commands;
		if (!commands) commands = @[@"/me", @"/msg", @"/nick", @"/join", @"/list", @"/away", @"/whois", @"/say", @"/raw", @"/quote", @"/quit", @"/disconnect", @"/query", @"/part", @"/notice", @"/onotice", @"/umode", @"/globops",
#if ENABLE(FILE_TRANSFERS)
		@"/dcc",
#endif
		@"/aaway", @"/anick", @"/aquit", @"/amsg", @"/ame", @"/google", @"/wikipedia", @"/amazon", @"/safari", @"/browser", @"/url", @"/clear", @"/nickserv", @"/chanserv", @"/help", @"/faq", @"/search", @"/ipod", @"/music", @"/squit", @"/welcome", @"/sysinfo", @"/ignore", @"/unignore", @"/giphy", @"/gif", @"/shrug" ];

		for (NSString *command in commands) {
			if ([command hasCaseInsensitivePrefix:word] && ![command isCaseInsensitiveEqualToString:word])
				[completions addObject:command];
			if (completions.count >= 10)
				break;
		}
	}

	if (completions.count < 10 && ([word containsTypicalEmoticonCharacters] || [word hasCaseInsensitivePrefix:@"x"] || [word hasCaseInsensitivePrefix:@"o"])) {
		for (NSString *emoticon in [NSString knownEmoticons]) {
			if ([emoticon hasCaseInsensitivePrefix:word] && ![emoticon isCaseInsensitiveEqualToString:word])	{
				if (graphicalEmoticons)
					[completions addObject:[emoticon stringBySubstitutingEmoticonsForEmoji]];
				else [completions addObject:emoticon];
			}

			if (completions.count >= 10)
				break;
		}
	}

	return completions;
}

- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar sendText:(MVChatString *) text {
	_didSendRecently = YES;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(resetDidSendRecently) object:nil];
	[self performSelector:@selector(resetDidSendRecently) withObject:nil afterDelay:0.5];

	if (!_target)
		return YES;

	return [self _sendText:text];
}

- (BOOL) chatInputBar:(CQChatInputBar *) theChatInputBar shouldChangeHeightBy:(CGFloat) difference {
	if (difference == 0)
		return NO;

	CGRect frame = transcriptView.frame;
	frame.size.height += difference;
	transcriptView.frame = frame;

	frame = chatInputBar.frame;
	frame.origin.y += difference;
	chatInputBar.frame = frame;

	return YES;
}

- (BOOL) chatInputBarShouldIndent:(CQChatInputBar *) chatInputBar {
	hardwareKeyboard = YES;
	[self _showChatCompletions];
	return NO;
}

- (void) chatInputBarDidChangeSelection:(CQChatInputBar *) chatInputBar {
	[self _updateAttributesForStyleViewController];
}

#pragma mark -

- (NSMutableAttributedString *) _selectedChatInputBarAttributedString {
	NSMutableAttributedString *attributedString = [chatInputBar.textView.attributedText mutableCopy];
	if (!attributedString) {
		attributedString = [[NSMutableAttributedString alloc] initWithString:(chatInputBar.textView.text ?: @"") attributes:@{
			NSFontAttributeName: chatInputBar.textView.font,
		}];
	}

	return attributedString;
}

- (void) _updateAttributesForStyleViewController {
	NSRange selectedRange = chatInputBar.textView.selectedRange;
	if (selectedRange.length == 0) {
		return;
	}

	NSMutableAttributedString *attributedString = self._selectedChatInputBarAttributedString;
	_styleViewController.attributes = [attributedString attributesAtIndex:selectedRange.location longestEffectiveRange:NULL inRange:selectedRange];
}

- (void) chatInputStyleView:(CQChatInputStyleViewController *) chatInputStyleView didChangeTextTrait:(CQTextTrait) trait toState:(BOOL) state {
	NSRange selectedRange = chatInputBar.textView.selectedRange;
	if (selectedRange.length == 0)
		return;

	NSMutableAttributedString *attributedString = self._selectedChatInputBarAttributedString;
	NSDictionary *newAttributes = nil;
	if (trait == CQTextTraitUnderline) {
		newAttributes = @{ NSUnderlineStyleAttributeName: (state ? @(NSUnderlineStyleSingle) : @(NSUnderlineStyleNone)) };
	} else {
		UIFont *font = [attributedString attribute:NSFontAttributeName atIndex:0 longestEffectiveRange:NULL inRange:NSMakeRange(0, attributedString.length)];
		if (!font)
			font = chatInputBar.textView.font;

		UIFontDescriptorSymbolicTraits symbolicTraits = font.fontDescriptor.symbolicTraits;
		if (trait == CQTextTraitItalic) {
			if (state) symbolicTraits |= UIFontDescriptorTraitItalic;
			else if (symbolicTraits & UIFontDescriptorTraitItalic) symbolicTraits ^= UIFontDescriptorTraitItalic;
		} else if (trait == CQTextTraitBold) {
			if (state) symbolicTraits |= UIFontDescriptorTraitBold;
			else if (symbolicTraits & UIFontDescriptorTraitBold) symbolicTraits ^= UIFontDescriptorTraitBold;
		} else return;

		UIFontDescriptor *fontDescriptor = [font.fontDescriptor fontDescriptorWithSymbolicTraits:symbolicTraits];
		newAttributes = @{ NSFontAttributeName: [UIFont fontWithDescriptor:fontDescriptor size:-1.] }; // -1 means use the currenet font descriptor's font
	}

	[[attributedString copy] enumerateAttributesInRange:selectedRange options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired usingBlock:^(NSDictionary *rangeAttributes, NSRange range, BOOL *stop) {
		NSMutableDictionary *attributes = [rangeAttributes mutableCopy];
		[attributes addEntriesFromDictionary:newAttributes];
		[attributedString setAttributes:attributes range:range];
	}];

	chatInputBar.textView.attributedText = attributedString;
	chatInputBar.textView.selectedRange = selectedRange;
}

- (void) chatInputStyleView:(CQChatInputStyleViewController *) chatInputStyleView didSelectColor:(UIColor *) color forColorPosition:(CQColorPosition) position {
	NSRange selectedRange = chatInputBar.textView.selectedRange;
	if (selectedRange.length == 0)
		return;

	NSMutableAttributedString *attributedString = self._selectedChatInputBarAttributedString;
	NSString *key = (position == CQColorPositionForeground ? NSForegroundColorAttributeName : NSBackgroundColorAttributeName);
	NSDictionary *newAttributes = color ? @{ key: color } : nil;

	[[attributedString copy] enumerateAttributesInRange:selectedRange options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired usingBlock:^(NSDictionary *rangeAttributes, NSRange range, BOOL *stop) {
		NSMutableDictionary *attributes = [rangeAttributes mutableCopy];
		if (newAttributes)
			[attributes addEntriesFromDictionary:newAttributes];
		else [attributes removeObjectForKey:key];
		[attributedString setAttributes:attributes range:range];
	}];

	chatInputBar.textView.attributedText = attributedString;
	chatInputBar.textView.selectedRange = selectedRange;
}

- (void) chatInputStyleViewShouldClose:(CQChatInputStyleViewController *) chatInputStyleView {
	[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];
	_styleViewController = nil;
}

#pragma mark -

- (void) importantChatMessageViewController:(CQImportantChatMessageViewController *) importantChatMessageViewController didSelectMessage:(MVChatString *) message isAction:(BOOL) isAction {
	[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:[UIView areAnimationsEnabled]];

	if (isAction) {
		NSDictionary *attributes = [message attributesAtIndex:0 effectiveRange:NULL];
		NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:@"/me " attributes:attributes];
		[attributedString appendAttributedString:message];

		chatInputBar.textView.attributedText = message;
	} else chatInputBar.textView.attributedText = message;

	[chatInputBar becomeFirstResponder];
}

#pragma mark -

- (void) clearController {
	[_pendingComponents removeAllObjects];

	_pendingPreviousSessionComponents = nil;
	_recentMessages = nil;

	[self markAsRead];

	[[NSNotificationCenter chatCenter] postNotificationName:CQChatViewControllerUnreadMessagesUpdatedNotification object:self];

	[transcriptView reset];
}

- (void) markAsRead {
	if (_unreadHighlightedMessages)
		[CQChatController defaultController].totalImportantUnreadCount -= _unreadHighlightedMessages;

	if (_unreadMessages && self.user)
		[CQChatController defaultController].totalImportantUnreadCount -= _unreadMessages;

	_unreadMessages = 0;
	_unreadHighlightedMessages = 0;
}

#pragma mark -

- (void) markScrollback {
	if (!markScrollbackOnMultitasking)
		return;

	[transcriptView markScrollback];
}

#pragma mark -

- (BOOL) _openURL:(NSURL *) url {
	[self _forceResignKeyboard];

	[[CQColloquyApplication sharedApplication] openURL:url options:@{} completionHandler:nil];

	return YES;
}

- (BOOL) _handleURLCommandWithArguments:(MVChatString *) arguments {
	NSScanner *scanner = [NSScanner scannerWithString:MVChatStringAsString(arguments)];
	NSString *urlString = nil;

	[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&urlString];

	if (!urlString.length)
		return NO;

	if ([MVChatStringAsString(arguments) isCaseInsensitiveEqualToString:@"last"])
		urlString = @"about:last";

	NSURL *url = (urlString ? [NSURL URLWithString:urlString] : nil);
	if (urlString && !url.scheme.length) url = [NSURL URLWithString:[@"http://" stringByAppendingString:urlString]];

	[self _openURL:url];

	return YES;
}

- (BOOL) handleConsoleCommandWithArguments:(MVChatString *) arguments {
	[[CQChatController defaultController] showConsoleForConnection:self.connection];

	return YES;
}

- (BOOL) handleBrowserCommandWithArguments:(MVChatString *) arguments {
	return [self _handleURLCommandWithArguments:arguments];
}

- (BOOL) handleSafariCommandWithArguments:(MVChatString *) arguments {
	return [self _handleURLCommandWithArguments:arguments];
}

- (BOOL) handleUrlCommandWithArguments:(MVChatString *) arguments {
	return [self handleSafariCommandWithArguments:arguments];
}

- (BOOL) handleAquitCommandWithArguments:(MVChatString *) arguments {
	for (MVChatConnection *connection in [CQConnectionsController defaultController].connectedConnections) {
		[connection disconnectWithReason:arguments];
	}
	return YES;
}

- (BOOL) handleAawayCommandWithArguments:(MVChatString *) arguments {
	for (MVChatConnection *connection in [CQConnectionsController defaultController].connectedConnections)
		connection.awayStatusMessage = arguments;
	return YES;
}

- (BOOL) handleAnickCommandWithArguments:(MVChatString *) arguments {
	for (MVChatConnection *connection in [CQConnectionsController defaultController].connectedConnections)
		connection.nickname = MVChatStringAsString(arguments);
	return YES;
}

- (BOOL) handleAmsgCommandWithArguments:(MVChatString *) arguments {
	NSArray <id <CQChatViewController>> *rooms = [[CQChatOrderingController defaultController] chatViewControllersOfClass:[CQChatRoomController class]];
	for (CQChatRoomController *controller in rooms) {
		if (!controller.connection.connected)
			continue;
		[controller sendMessage:arguments asAction:NO];
	}

	return YES;
}

- (BOOL) handleAmeCommandWithArguments:(MVChatString *) arguments {
	NSArray <id <CQChatViewController>> *rooms = [[CQChatOrderingController defaultController] chatViewControllersOfClass:[CQChatRoomController class]];
	for (CQChatRoomController *controller in rooms) {
		if (!controller.connection.connected)
			continue;
		[controller sendMessage:arguments asAction:YES];
	}

	return YES;
}

- (BOOL) handleJoinCommandWithArguments:(MVChatString *__nullable) arguments {
	if (![MVChatStringAsString(arguments) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length) {
		[self _showChatCreationViewController];

		return YES;
	}

	[self.connection connectAppropriately];

	NSArray <NSString *> *rooms = [MVChatStringAsString(arguments) componentsSeparatedByString:@","];
	if (((NSString *)rooms.firstObject).length)
		[[CQChatController defaultController] showChatControllerWhenAvailableForRoomNamed:rooms.firstObject andConnection:self.connection];

	// Return NO so the command is handled in ChatCore.
	return NO;
}

- (BOOL) handleJCommandWithArguments:(MVChatString *) arguments {
	return [self handleJoinCommandWithArguments:arguments];
}

- (BOOL) handleMsgCommandWithArguments:(MVChatString *) arguments {
	if (!arguments.length) {
		[self _showChatCreationViewController];

		return YES;
	}

	NSScanner *argumentsScanner = [NSScanner scannerWithString:MVChatStringAsString(arguments)];
	[argumentsScanner setCharactersToBeSkipped:nil];

	NSString *targetName = nil;
	[argumentsScanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&targetName];

	if (targetName.length > 1 && [[self.connection chatRoomNamePrefixes] characterIsMember:[targetName characterAtIndex:0]]) {
		MVChatRoom *room = [self.connection chatRoomWithUniqueIdentifier:targetName];
		CQChatRoomController *controller = [[CQChatOrderingController defaultController] chatViewControllerForRoom:room ifExists:NO];
		if (controller) [[CQChatController defaultController] showChatController:controller animated:YES];
	} else {
		MVChatUser *user = [[self.connection chatUsersWithNickname:targetName] anyObject];
		CQDirectChatController *controller = [[CQChatOrderingController defaultController] chatViewControllerForUser:user ifExists:NO];
		[[CQChatController defaultController] showChatController:controller animated:YES];
		if (controller) [[CQChatController defaultController] showChatController:controller animated:YES];
	}

	// If we have a message, return NO so the command is handled in ChatCore.
	return [argumentsScanner isAtEnd];
}

- (BOOL) handleNoticeCommandWithArguments:(MVChatString *) arguments {
	NSScanner *argumentsScanner = [NSScanner scannerWithString:MVChatStringAsString(arguments)];
	argumentsScanner.charactersToBeSkipped = nil;

	NSString *target = nil;
	[argumentsScanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&target];

	if (target.length > 2) {
		MVChatRoom *room = nil;
		if ([[self.connection chatRoomNamePrefixes] characterIsMember:[target characterAtIndex:0]])
			room = [self.connection chatRoomWithUniqueIdentifier:target];
		else if ([[self.connection chatRoomNamePrefixes] characterIsMember:[target characterAtIndex:1]])
			room = [self.connection chatRoomWithUniqueIdentifier:[target substringFromIndex:1]];

		if (!room)
			return NO;

		NSAttributedString *message = [arguments attributedSubstringFromIndex:argumentsScanner.scanLocation];
		NSData *messageData = [message chatFormatWithOptions:@{
			@"FormatType": NSChatWindowsIRCFormatType,
			@"StringEncoding": @(_encoding),
		}];
		CQChatRoomController *controller = [[CQChatOrderingController defaultController] chatViewControllerForRoom:room ifExists:YES];
		[controller addMessage:@{ @"message": messageData, @"type": @"message", @"notice": @(YES), @"user": self.connection.localUser }];
	}

	// Return NO so the command is handled in ChatCore.
	return NO;
}

- (BOOL) handleOnoticeCommandWithArguments:(MVChatString *) arguments {
	if ([MVChatStringAsString(arguments) hasPrefix:@"@"])
		return [self handleNoticeCommandWithArguments:arguments];

	NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:@"@"];
	[attributedString appendAttributedString:arguments];
	return [self handleNoticeCommandWithArguments:attributedString];
}

- (BOOL) handleQueryCommandWithArguments:(MVChatString *) arguments {
	return [self handleMsgCommandWithArguments:arguments];
}

- (BOOL) handleClearCommandWithArguments:(MVChatString *) arguments {
	[self clearController];

	return YES;
}

- (BOOL) handleMusicCommandWithArguments:(MVChatString *) arguments {
#if !SYSTEM(TV)
	MPMusicPlayerController *musicController = [MPMusicPlayerController systemMusicPlayer];
	MPMediaItem *nowPlayingItem = musicController.nowPlayingItem;

	NSString *argumentsString = MVChatStringAsString(arguments);
	if ([argumentsString isCaseInsensitiveEqualToString:@"next"] || [argumentsString isCaseInsensitiveEqualToString:@"skip"] || [argumentsString isCaseInsensitiveEqualToString:@"forward"])
		[musicController skipToNextItem];
	else if ([argumentsString isCaseInsensitiveEqualToString:@"previous"] || [argumentsString isCaseInsensitiveEqualToString:@"back"])
		[musicController skipToPreviousItem];
	else if ([argumentsString isCaseInsensitiveEqualToString:@"stop"] || [argumentsString isCaseInsensitiveEqualToString:@"pause"])
		[musicController stop];
	else if ([argumentsString isCaseInsensitiveEqualToString:@"play"] || [argumentsString isCaseInsensitiveEqualToString:@"resume"])
		[musicController play];

	if (arguments.length)
		return YES;

	NSString *message = nil;
	if (nowPlayingItem && musicController.playbackState == MPMusicPlaybackStatePlaying) {
		NSString *title = [nowPlayingItem valueForProperty:MPMediaItemPropertyTitle];
		NSString *artist = [nowPlayingItem valueForProperty:MPMediaItemPropertyArtist];
		NSString *album = [nowPlayingItem valueForProperty:MPMediaItemPropertyAlbumTitle];

		if (title.length && artist.length && album.length)
			message = [NSString stringWithFormat:NSLocalizedString(@"is listening to %@ by %@ from %@.", @"Listening to music by an artist from an album"), title, artist, album];
		else if (title.length && artist.length)
			message = [NSString stringWithFormat:NSLocalizedString(@"is listening to %@ by %@.", @"Listening to music by an artist"), title, artist];
		else if (title.length && album.length)
			message = [NSString stringWithFormat:NSLocalizedString(@"is listening to %@ from %@.", @"Listening to music from an album"), title, album];
		else if (title.length)
			message = [NSString stringWithFormat:NSLocalizedString(@"is listening to %@.", @"Listening to music"), title];
		else message = NSLocalizedString(@"is listening to an untitled song.", @"Listening to untitled music");
	} else {
		message = NSLocalizedString(@"is not currently listening to music.", @"Not listening to music message");
	}

	[self sendMessage:[[NSAttributedString alloc] initWithString:message] asAction:YES];
#endif

	return YES;
}

- (BOOL) handleIpodCommandWithArguments:(MVChatString *) arguments {
	return [self handleMusicCommandWithArguments:arguments];
}

- (BOOL) handleItunesCommandWithArguments:(MVChatString *) arguments {
	return [self handleMusicCommandWithArguments:arguments];
}

- (BOOL) handleNpCommandWithArguments:(MVChatString *) arguments {
	return [self handleMusicCommandWithArguments:arguments];
}

- (BOOL) handleSquitCommandWithArguments:(MVChatString *) arguments {
	if (self.connection.directConnection)
		return NO;

	[self.connection sendRawMessageImmediatelyWithComponents:@"SQUIT :", arguments, nil];

	return YES;
}

- (BOOL) handleListCommandWithArguments:(MVChatString *) arguments {
	CQChatCreationViewController *creationViewController = [[CQChatCreationViewController alloc] init];
	creationViewController.roomTarget = YES;
	creationViewController.selectedConnection = self.connection;

	[creationViewController showRoomListFilteredWithSearchString:MVChatStringAsString(arguments)];

	[self _forceResignKeyboard];

	[[CQColloquyApplication sharedApplication] presentModalViewController:creationViewController animated:YES];

	return YES;
}

#pragma mark -

- (id) _findLocaleForQueryWithArguments:(MVChatString *) arguments {
	NSScanner *argumentsScanner = [NSScanner scannerWithString:MVChatStringAsString(arguments)];
	[argumentsScanner setCharactersToBeSkipped:nil];

	NSString *languageCode = nil;
	[argumentsScanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&languageCode];

	NSMutableArray *results = [[NSMutableArray alloc] init];
	if (!languageCode.length || languageCode.length != 2) {
		languageCode = [[NSLocale autoupdatingCurrentLocale] localeIdentifier];

		[results addObject:languageCode];
		[results addObject:arguments];

		return results;
	}

	NSString *query = nil;
	if (arguments.length >= (argumentsScanner.scanLocation + 1))
		query = [MVChatStringAsString(arguments) substringWithRange:NSMakeRange(argumentsScanner.scanLocation + 1, (arguments.length - argumentsScanner.scanLocation - 1))];
	else query = MVChatStringAsString(arguments);

	[results addObject:languageCode];
	[results addObject:query];

	return results;
}

- (void) _handleSearchForURL:(NSString *) urlFormatString withQuery:(NSString *) query {
	NSString *urlString = [NSString stringWithFormat:urlFormatString, [query stringByEncodingIllegalURLCharacters]];
	NSURL *url = [NSURL URLWithString:urlString];
	[self _openURL:url];
}

- (void) _handleSearchForURL:(NSString *) urlFormatString withQuery:(NSString *) query withLocale:(NSString *) languageCode {
	NSString *urlString = [NSString stringWithFormat:urlFormatString, [query stringByEncodingIllegalURLCharacters], languageCode];
	NSURL *url = [NSURL URLWithString:urlString];
	[self _openURL:url];
}

- (BOOL) handleGoogleCommandWithArguments:(MVChatString *) arguments {
	NSMutableArray *results = [self _findLocaleForQueryWithArguments:arguments];
	NSString *languageCode = results[0];
	NSString *query = results[1];

	[self _handleSearchForURL:@"https://www.google.com/m/search?q=%@&hl=%@" withQuery:query withLocale:languageCode];

	return YES;
}

- (BOOL) handleWikipediaCommandWithArguments:(MVChatString *) arguments {
	NSArray <NSString *> *results = [self _findLocaleForQueryWithArguments:arguments];
	NSString *languageCode = results[0];
	NSString *query = results[1];

	[self _handleSearchForURL:@"https://www.wikipedia.org/search-redirect.php?search=%@&language=%@" withQuery:query withLocale:languageCode];

	return YES;
}

- (BOOL) handleAmazonCommandWithArguments:(MVChatString *) arguments {
	NSArray <NSString *> *results = [self _findLocaleForQueryWithArguments:arguments];
	NSString *languageCode = results[0];
	NSString *query = results[1];

	if ([languageCode isCaseInsensitiveEqualToString:@"en_gb"])
		[self _handleSearchForURL:@"https://www.amazon.co.uk/s/field-keywords=%@" withQuery:query withLocale:languageCode];
	else if ([languageCode isCaseInsensitiveEqualToString:@"de"])
		[self _handleSearchForURL:@"https://www.amazon.de/gp/aw/s.html?k=%@" withQuery:query withLocale:languageCode];
	else if ([languageCode isCaseInsensitiveEqualToString:@"cn"])
		[self _handleSearchForURL:@"https://www.amazon.cn/mn/searchApp?&keywords=%@" withQuery:query withLocale:languageCode];
	else if ([languageCode isCaseInsensitiveEqualToString:@"ja_jp"])
		[self _handleSearchForURL:@"https://www.amazon.co.jp/s/field-keywords=%@" withQuery:query withLocale:languageCode];
	else if ([languageCode isCaseInsensitiveEqualToString:@"fr"])
		[self _handleSearchForURL:@"https://www.amazon.fr/s/field-keywords=%@" withQuery:query withLocale:languageCode];
	else if ([languageCode isCaseInsensitiveEqualToString:@"ca"])
		[self _handleSearchForURL:@"https://www.amazon.ca/s/field-keywords=%@" withQuery:query withLocale:languageCode];
	else [self _handleSearchForURL:@"https://www.amazon.com/gp/aw/s.html?k=%@" withQuery:query withLocale:languageCode];

	return YES;
}

- (BOOL) handleGifCommandWithArguments:(MVChatString *) arguments {
	[[[CQGiphyController alloc] init] searchFor:MVChatStringAsString(arguments) completion:^(CQGiphyResult * _Nullable result) {
		if (!result)
			return;

		[self sendMessage:[[NSAttributedString alloc] initWithString:result.GIFURL.absoluteString] asAction:NO];
	}];

	return YES;
}

- (BOOL) handleGiphyCommandWithArguments:(MVChatString *) arguments {
	return [self handleGifCommandWithArguments:arguments];
}

- (BOOL) handleShrugCommandWithArguments:(MVChatString *) arguments {
	static NSString *const shrug = @"¯\\_(ツ)_/¯";
	NSString *trimmed = [MVChatStringAsString(arguments) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!trimmed.length) {
		[self sendMessage:[[NSAttributedString alloc] initWithString:shrug] asAction:NO];
		return YES;
	}

	if (![trimmed hasSuffix:shrug]) {
#if( defined(USE_ATTRIBUTED_CHAT_STRING) && USE_ATTRIBUTED_CHAT_STRING )
		NSMutableAttributedString *stringWithShrug = [arguments mutableCopy];
		NSDictionary *attributes = [stringWithShrug attributesAtIndex:arguments.length - 1 effectiveRange:NULL];
		[stringWithShrug appendAttributedString:[[NSAttributedString alloc] initWithString:shrug attributes:attributes]];
		[stringWithShrug deleteCharactersInRange:NSMakeRange(0, @"/shrug".length)];

		[self sendMessage:stringWithShrug asAction:NO];
#else
		NSMutableString *stringWithShrug = [arguments mutableCopy];
		[stringWithShrug appendString:shrug];
		[stringWithShrug deleteCharactersInRange:NSMakeRange(0, @"/shrug".length)];

		[self sendMessage:stringWithShrug asAction:NO];
#endif
	}

	return YES;
}

- (BOOL) handleHelpCommandWithArguments:(MVChatString *) arguments {
	[self _forceResignKeyboard];

	[[CQColloquyApplication sharedApplication] showHelp:nil];

	return YES;
}

- (BOOL) handleFaqCommandWithArguments:(MVChatString *) arguments {
	[self handleHelpCommandWithArguments:arguments];

	return YES;
}

- (BOOL) handleWelcomeCommandWithArguments:(MVChatString *) arguments {
	[self _forceResignKeyboard];

	[[CQColloquyApplication sharedApplication] showWelcome:nil];

	return YES;
}

- (BOOL) handleSearchCommandWithArguments:(MVChatString *) arguments {
	NSString *urlString = @"http://searchirc.com/search.php?F=partial&I=%@&T=both&N=all&M=min&C=5&PER=20";

	[self _handleSearchForURL:urlString withQuery:MVChatStringAsString(arguments)];

	return YES;
}

- (BOOL) handleTweetCommandWithArguments:(MVChatString *) arguments {
#if !SYSTEM(TV)
	SLComposeViewController *composeViewController = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
	NSString *selectedText = transcriptView.selectedText;

	if (selectedText.length) {
		NSURL *url = [NSURL URLWithString:selectedText];
		if (url) {
			[composeViewController addURL:url];
		} else {
			[composeViewController setInitialText:selectedText];
		}
	} else {
		if ([UIPasteboard generalPasteboard].string.length)
			[composeViewController setInitialText:[UIPasteboard generalPasteboard].string];

		if ([UIPasteboard generalPasteboard].URL)
			[composeViewController addURL:[UIPasteboard generalPasteboard].URL];

		if ([UIPasteboard generalPasteboard].image)
			[composeViewController addImage:[UIPasteboard generalPasteboard].image];
	}

	composeViewController.completionHandler = ^(SLComposeViewControllerResult result) { /* do nothing */ };
	[self.navigationController presentViewController:composeViewController animated:YES completion:NULL];
#endif

	return YES;
}

- (BOOL) handleSysinfoCommandWithArguments:(MVChatString *) arguments {
	NSString *version = [[CQSettingsController settingsController] stringForKey:@"CQCurrentVersion"];
#if !SYSTEM(TV)
	NSString *orientation = UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation) ? NSLocalizedString(@"landscape", @"landscape orientation") : NSLocalizedString(@"portrait", @"portrait orientation");
#else
	NSString *orientation = NSLocalizedString(@"landscape", @"landscape orientation");
#endif
	NSString *model = [UIDevice currentDevice].localizedModel;
	NSString *systemVersion = [NSProcessInfo processInfo].operatingSystemVersionString;
	NSString *systemUptime = humanReadableTimeInterval([NSProcessInfo processInfo].systemUptime);
	NSUInteger processorsInTotal = [NSProcessInfo processInfo].processorCount;

	long long physicalMemory = [NSProcessInfo processInfo].physicalMemory;
	NSString *systemMemory = [NSByteCountFormatter stringFromByteCount:physicalMemory countStyle:NSByteCountFormatterCountStyleBinary];

	NSString *message = nil;
#if !SYSTEM(TV)
	BOOL batteryMonitoringEnabled = [UIDevice currentDevice].batteryMonitoringEnabled;
	[UIDevice currentDevice].batteryMonitoringEnabled = YES;
	if ([UIDevice currentDevice].batteryState >= UIDeviceBatteryStateUnplugged)
		message = [NSString stringWithFormat:NSLocalizedString(@"is running Mobile Colloquy %@ in %@ mode on an %@ running iOS %@ with %d processors, %@ RAM, %.0f%% battery life remaining and a system uptime of %@.", @"System info message with battery level"), version, orientation, model, systemVersion, processorsInTotal, systemMemory, [UIDevice currentDevice].batteryLevel * 100., systemUptime];
	else
#endif
		message = [NSString stringWithFormat:NSLocalizedString(@"is running Mobile Colloquy %@ in %@ mode on an %@ running iOS %@ with %d processors, %@ RAM and a system uptime of %@.", @"System info message"), version, orientation, model, systemVersion, processorsInTotal, systemMemory, systemUptime];
#if !SYSTEM(TV)
	[UIDevice currentDevice].batteryMonitoringEnabled = batteryMonitoringEnabled;
#endif

	[self sendMessage:[[NSAttributedString alloc] initWithString:message] asAction:YES];

	return YES;
}

- (void) handleZncCommandWithArguments:(MVChatString *) arguments {
	NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:@"*status "];
	[attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:MVChatStringAsString(arguments)]];
	[self handleMsgCommandWithArguments:attributedString];
}

#pragma mark -

- (BOOL) handleWhoisCommandWithArguments:(MVChatString *) arguments {
	if (arguments.length) {
		NSString *nick = [MVChatStringAsString(arguments) componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]][0];
		[self _showUserInfoControllerForUserNamed:nick];
	} else if (self.user) {
		[self _showUserInfoControllerForUser:self.user];
	} else {
		return NO;
	}

	return YES;
}

- (BOOL) handleWiCommandWithArguments:(MVChatString *) arguments {
	return [self handleWhoisCommandWithArguments:arguments];
}

- (BOOL) handleWiiCommandWithArguments:(MVChatString *) arguments {
	return [self handleWhoisCommandWithArguments:arguments];
}

#if ENABLE(FILE_TRANSFERS)
- (BOOL) handleDccCommandWithArguments:(MVChatString *) arguments {
	if (!arguments.length)
		return NO;

	NSString *nick = [[arguments componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] objectAtIndex:0];
	MVChatUser *user = [[self.connection chatUsersWithNickname:nick] anyObject];
	[[CQChatController defaultController] showFilePickerWithUser:user];

	return YES;
}
#endif

#pragma mark -

- (BOOL) handleIgnoreCommandWithArguments:(MVChatString *) arguments {
	KAIgnoreRule *ignoreRule = nil;

	NSString *argumentsString = MVChatStringAsString(arguments);
	if (argumentsString.isValidIRCMask)
		ignoreRule = [KAIgnoreRule ruleForUser:nil mask:argumentsString message:nil inRooms:nil isPermanent:YES friendlyName:nil];
	else ignoreRule = [KAIgnoreRule ruleForUser:argumentsString mask:nil message:nil inRooms:nil isPermanent:YES friendlyName:nil];

	[self.connection.ignoreController addIgnoreRule:ignoreRule];

	return YES;
}

- (BOOL) handleUnignoreCommandWithArguments:(MVChatString *) arguments {
	[self.connection.ignoreController removeIgnoreRuleFromString:MVChatStringAsString(arguments)];

	return YES;
}

#pragma mark -

- (BOOL) handleTokenCommandWithArguments:(MVChatString *__nullable) arguments {
#if !TARGET_IPHONE_SIMULATOR
	if (![CQColloquyApplication sharedApplication].deviceToken.length) {
		_showDeviceTokenWhenRegistered = YES;
		[[CQColloquyApplication sharedApplication] registerForPushNotifications];
		return YES;
	}

	[self addEventMessage:NSLocalizedString(@"Your device token is only shown locally and is:", @"Your device token is only shown locally and is:") withIdentifier:@"token"];
	[self addEventMessage:[CQColloquyApplication sharedApplication].deviceToken withIdentifier:@"token"];
#else
	[self addEventMessage:@"Push notifications not supported in the simulator." withIdentifier:@"token"];
#endif

	return YES;
}

- (void) handleResetbadgeCommandWithArguments:(MVChatString *) arguments {
#if !SYSTEM(TV)
	[CQColloquyApplication sharedApplication].applicationIconBadgeNumber = 0;
#endif
}

#pragma mark -

- (void) _handleKeyCommand:(UIKeyCommand *) command {
	id nextViewController = nil;

	BOOL optKeyPressed = (command.modifierFlags & UIKeyModifierAlternate) == UIKeyModifierAlternate;
	BOOL shiftKeyPressed = (command.modifierFlags & UIKeyModifierShift) == UIKeyModifierShift;
	BOOL commandKeyPressed = (command.modifierFlags & UIKeyModifierCommand) == UIKeyModifierCommand;

	if ([command.input isEqualToString:@"c"]) {
		if (commandKeyPressed && shiftKeyPressed)
			[self style:nil];
	} else if ([command.input isEqualToString:@"j"]) {
		if (commandKeyPressed)
			[self handleJoinCommandWithArguments:nil];
	} else if ([command.input isEqualToString:@"k"]) {
		if (commandKeyPressed && shiftKeyPressed)
			[self clearController];
	} else if ([command.input isEqualToString:@"n"]) {
		if (commandKeyPressed && !shiftKeyPressed)
			[[CQConnectionsController defaultController] showConnectionCreationView:nil];
		else [self handleJoinCommandWithArguments:nil];
	} else if ([command.input isEqualToString:@"\t"]) {
		if (optKeyPressed) {
			if (shiftKeyPressed)
				nextViewController = [[CQChatOrderingController defaultController] chatViewControllerPreceedingChatController:self requiringActivity:NO requiringHighlight:NO];
			else nextViewController = [[CQChatOrderingController defaultController] chatViewControllerFollowingChatController:self requiringActivity:NO requiringHighlight:NO];
		}
	} else if ([command.input isEqualToString:UIKeyInputUpArrow]) {
		if (commandKeyPressed)
			nextViewController = [[CQChatOrderingController defaultController] chatViewControllerPreceedingChatController:self requiringActivity:optKeyPressed requiringHighlight:NO];
	} else if ([command.input isEqualToString:UIKeyInputDownArrow]) {
		if (commandKeyPressed)
			nextViewController = [[CQChatOrderingController defaultController] chatViewControllerFollowingChatController:self requiringActivity:optKeyPressed requiringHighlight:NO];
	} else if ([command.input isEqualToString:UIKeyInputEscape]) {
		[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:YES];
		[[CQColloquyApplication sharedApplication] dismissPopoversAnimated:YES];
	}

	if (nextViewController)
		[[CQChatController defaultController] showChatController:nextViewController animated:NO];
}

#pragma mark -

- (void) transcriptView:(id) transcriptView receivedSwipeWithTouchCount:(NSUInteger) touchCount leftward:(BOOL) leftward {
	CQSwipeMeaning meaning = CQSwipeDisabled;
	if (touchCount == 1)
		meaning = (CQSwipeMeaning)singleSwipeGesture;
	else if (touchCount == 2)
		meaning = (CQSwipeMeaning)doubleSwipeGesture;
	else if (touchCount == 3)
		meaning = (CQSwipeMeaning)tripleSwipeGesture;

	id <CQChatViewController> nextViewController = nil;
	if (meaning == CQSwipeNextRoom) {
		if (leftward)
			nextViewController = [[CQChatOrderingController defaultController] chatViewControllerFollowingChatController:self requiringActivity:NO requiringHighlight:NO];
		else nextViewController = [[CQChatOrderingController defaultController] chatViewControllerPreceedingChatController:self requiringActivity:NO requiringHighlight:NO];
	} else if (meaning == CQSwipeNextActiveRoom) {
		if (leftward)
			nextViewController = [[CQChatOrderingController defaultController] chatViewControllerFollowingChatController:self requiringActivity:YES requiringHighlight:NO];
		else nextViewController = [[CQChatOrderingController defaultController] chatViewControllerPreceedingChatController:self requiringActivity:YES requiringHighlight:NO];
	} else if (meaning == CQSwipeNextHighlight) {
		if (leftward)
			nextViewController = [[CQChatOrderingController defaultController] chatViewControllerFollowingChatController:self requiringActivity:NO requiringHighlight:YES];
		else nextViewController = [[CQChatOrderingController defaultController] chatViewControllerPreceedingChatController:self requiringActivity:NO requiringHighlight:YES];
	} else return;

	if (nextViewController) {
		NSMutableArray *viewStack = [self.navigationController.viewControllers mutableCopy];
		[viewStack removeLastObject];
		[viewStack addObject:nextViewController];

		self.navigationController.viewControllers = viewStack;
	}
}

- (BOOL) transcriptView:(id) transcriptView handleOpenURL:(NSURL *) url {
	if (![url.scheme isCaseInsensitiveEqualToString:@"irc"] && ![url.scheme isCaseInsensitiveEqualToString:@"ircs"])
		return [self _openURL:url];

	if (!url.host.length) {
		NSString *target = @"";
		if (url.fragment.length) target = [@"#" stringByAppendingString:url.fragment];
		else if (url.path.length > 1) target = url.path;

		url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@/%@", url.scheme, self.connection.server, target]];
	}

	[[CQColloquyApplication sharedApplication] openURL:url options:@{} completionHandler:nil];

	return YES;
}

- (void) transcriptView:(id) transcriptView handleNicknameTap:(NSString *) nickname atLocation:(CGPoint) location {
	[self _showUserInfoControllerForUserNamed:nickname];
}

- (void) transcriptView:(id) transcriptView handleLongPressURL:(NSURL *) url atLocation:(CGPoint) location {
	CQActionSheet *actionSheet = [[CQActionSheet alloc] init];
	actionSheet.delegate = self;
	actionSheet.tag = URLActionSheet;
	actionSheet.title = url.absoluteString;

	[actionSheet addButtonWithTitle:NSLocalizedString(@"Open", @"Open button title")];
	if ([CQBookmarkingController activeService])
		[actionSheet addButtonWithTitle:[[CQBookmarkingController activeService] serviceName]];
	[actionSheet addButtonWithTitle:NSLocalizedString(@"Copy", @"Copy button title")];
	actionSheet.cancelButtonIndex = [actionSheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	[actionSheet associateObject:url forKey:@"URL"];

	[[CQColloquyApplication sharedApplication] showActionSheet:actionSheet fromPoint:location];
}

- (BOOL) transcriptViewShouldBecomeFirstResponder:(id) transcriptView {
	return chatInputBar.isFirstResponder;
}

- (void) transcriptViewWasReset:(id) view {
	if (_pendingPreviousSessionComponents.count) {
		[view addPreviousSessionComponents:_pendingPreviousSessionComponents];

		_pendingPreviousSessionComponents = nil;
	} else if (_recentMessages.count) {
		[view addPreviousSessionComponents:_recentMessages];
	}
}

#pragma mark -

- (void) resetDidSendRecently {
	_didSendRecently = NO;
}

- (void) checkTranscriptViewForBecomeFirstResponder {
	if (_didSendRecently || ![transcriptView canBecomeFirstResponder])
		return;

	[self _forceResignKeyboard];
}

- (void) setScrollbackLength:(NSUInteger) scrollbackLength {
	transcriptView.scrollbackLimit = scrollbackLength;
}

- (void) setMostRecentIncomingMessageTimestamp:(NSDate *) date {
	if( !_mostRecentIncomingMessageTimestamp || [date laterDate:_mostRecentIncomingMessageTimestamp] == date)
		MVSafeCopyAssign( _mostRecentIncomingMessageTimestamp, date );
}

- (void) setMostRecentOutgoingMessageTimestamp:(NSDate *) date {
	if( !_mostRecentOutgoingMessageTimestamp || [date laterDate:_mostRecentOutgoingMessageTimestamp] == date)
		MVSafeCopyAssign( _mostRecentOutgoingMessageTimestamp, date );
}

#pragma mark -

- (void) keyboardWillShow:(NSNotification *) notification {
	_showingKeyboard = YES;

	if (![self isViewLoaded] || !self.view.window)
		return;

	CGRect keyboardRect = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
	keyboardRect = [self.view.window convertRect:keyboardRect toView:self.view];

	NSTimeInterval animationDuration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
	NSUInteger animationCurve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue];
	[UIView animateWithDuration:(cq_shouldAnimate(_active) ? animationDuration : .0) delay:.0 options:animationCurve animations:^{
		CGRect frame = containerView.frame;
		frame.size.height = CGRectGetMinY(keyboardRect);
		containerView.frame = frame;
	} completion:NULL];

	[transcriptView scrollToBottomAnimated:_active];
}

- (void) keyboardWillHide:(NSNotification *) notification {
	if (!_showingKeyboard)
		return;

	_showingKeyboard = NO;

	if (![self isViewLoaded])
		return;

	NSTimeInterval animationDuration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
	NSUInteger animationCurve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue];

	[UIView animateWithDuration:(cq_shouldAnimate(_active && self.view.window) ? animationDuration : .0) delay:.0 options:(animationCurve << 16) animations:^{
		containerView.frame = self.view.bounds;
	} completion:NULL];
}

#pragma mark -

- (void) scrollbackLengthDidChange:(NSNotification *) notification {
	[self setScrollbackLength:scrollbackLength];
}

#pragma mark -

- (void) sendMessage:(MVChatString *) message asAction:(BOOL) action {
	[_target sendMessage:message withEncoding:self.encoding asAction:action];

	[_sentMessages addObject:@{ @"message": message, @"action": @(action) }];
	while (_sentMessages.count > 10)
		[_sentMessages removeObjectAtIndex:0];

	// if the server echos things back for us, we don't have to add it ourself
	if ([self.connection.supportedFeatures containsObject:MVChatConnectionEchoMessageFeature])
		return;

	NSData *messageData = [message chatFormatWithOptions:@{
		@"FormatType": NSChatWindowsIRCFormatType,
		@"StringEncoding": @(_encoding),
	}];
	[self addMessage:messageData fromUser:self.connection.localUser asAction:action withIdentifier:[NSString locallyUniqueString]];
}

- (BOOL) _sendText:(MVChatString *) text {
	BOOL didSendText = NO;
	for (__strong NSAttributedString *line in [text cq_componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
		line = [line cq_stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		if (line.length)
			didSendText = [self _sendLineOfText:line] || didSendText; // send text first to not short-circuit and stop
	}
	return didSendText;
}

- (BOOL ) _sendLineOfText:(MVChatString *) text {
	NSString *argumentString = MVChatStringAsString(text);
	if ([argumentString hasPrefix:@"/"] && ![argumentString hasPrefix:@"//"] && argumentString.length > 1) {
		static NSSet *commandsNotRequiringConnection;
		if (!commandsNotRequiringConnection)
			commandsNotRequiringConnection = [[NSSet alloc] initWithObjects:@"google", @"wikipedia", @"amazon", @"safari", @"browser", @"url", @"clear", @"help", @"faq", @"search", @"list", @"join", @"welcome", @"token", @"resetbadge", @"tweet", @"aquit", @"anick", @"aaway", nil];

		// Send as a command.
		NSScanner *scanner = [NSScanner scannerWithString:argumentString];
		[scanner setCharactersToBeSkipped:nil];

		NSString *command = nil;
		NSAttributedString *arguments = nil;

		scanner.scanLocation = 1; // Skip the "/" prefix.

		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&command];
		if (!self.available && ([command isCaseInsensitiveEqualToString:@"me"] || [command isCaseInsensitiveEqualToString:@"msg"] || [command isCaseInsensitiveEqualToString:@"say"])) {
			[self _showCantSendMessagesWarningForCommand:NO];
			return NO;
		}

		if (!self.connection.connected && ![commandsNotRequiringConnection containsObject:[command lowercaseString]]) {
			[self _showCantSendMessagesWarningForCommand:YES];
			return NO;
		}

		[scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] maxLength:1 intoString:NULL];

		arguments = [text attributedSubstringFromIndex:scanner.scanLocation];

		NSString *commandSelectorString = [NSString stringWithFormat:@"handle%@CommandWithArguments:", [command capitalizedString]];
		SEL commandSelector = NSSelectorFromString(commandSelectorString);

		BOOL handled = NO;
		if ([self respondsToSelector:commandSelector])
			handled = ((BOOL (*)(id, SEL, NSAttributedString *))objc_msgSend)(self, commandSelector, arguments);

		if (!handled) [_target sendCommand:command withArguments:arguments withEncoding:self.encoding];
	} else {
		if (!self.available) {
			[self _showCantSendMessagesWarningForCommand:NO];
			return NO;
		}

		// Send as a message, strip the first forward slash if it exists.
		if ([argumentString hasPrefix:@"/"] && argumentString.length > 1)
			text = [text attributedSubstringFromIndex:1];

		__block BOOL action = NO;

		if (naturalChatActions && !action) {
			static NSSet *actionVerbs;
			if (!actionVerbs) {
				NSArray <NSString *> *verbs = [[NSArray alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"verbs" ofType:@"plist"]];
				actionVerbs = [[NSSet alloc] initWithArray:verbs];
			}

			NSScanner *scanner = [[NSScanner alloc] initWithString:argumentString];
			scanner.charactersToBeSkipped = nil;

			NSString *word = nil;
			[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&word];

			if ([actionVerbs containsObject:word])
				action = YES;
		}

		[self sendMessage:text asAction:action];
	}
	
	return YES;
}

#pragma mark -

- (void) addEventMessage:(NSString *) messageString withIdentifier:(NSString *) identifier {
	[self addEventMessage:messageString withIdentifier:identifier announceWithVoiceOver:NO];
}

- (void) addEventMessage:(NSString *) messageString withIdentifier:(NSString *) identifier announceWithVoiceOver:(BOOL) announce {
	[self addEventMessageAsHTML:[messageString stringByEncodingXMLSpecialCharactersAsEntities] withIdentifier:identifier announceWithVoiceOver:announce];
}

- (void) addEventMessageAsHTML:(NSString *) messageString withIdentifier:(NSString *) identifier {
	[self addEventMessageAsHTML:messageString withIdentifier:identifier announceWithVoiceOver:NO];
}

- (void) addEventMessageAsHTML:(NSString *) messageString withIdentifier:(NSString *) identifier announceWithVoiceOver:(BOOL) announce {
	if (!identifier.length) identifier = @"";
	NSMutableDictionary *message = [[NSMutableDictionary alloc] init];

	message[@"type"] = @"event";

	if (messageString) message[@"message"] = messageString;
	if (identifier) message[@"identifier"] = identifier;

	[self _addPendingComponent:message];

	if (announce && [self canAnnounceWithVoiceOverAndMessageIsImportant:NO]) {
		NSString *voiceOverAnnouncement = nil;
		NSString *plainMessage = [messageString stringByStrippingXMLTags];
		plainMessage = [plainMessage stringByDecodingXMLSpecialCharacterEntities];

		__weak static id weakAccessibilityTarget = nil;
		id accessibilityTarget = weakAccessibilityTarget;
		if (!accessibilityTarget || accessibilityTarget == self.target) {
			voiceOverAnnouncement = plainMessage;
		} else {
			weakAccessibilityTarget = self.target;

			if ([self isMemberOfClass:[CQDirectChatController class]])
				voiceOverAnnouncement = [NSString stringWithFormat:NSLocalizedString(@"%@ said %@", @"Voiceover event announcement (private message)"), self.title, plainMessage];
			else voiceOverAnnouncement = [NSString stringWithFormat:NSLocalizedString(@"In %@, %@", @"VoiceOver event announcement (chat room)"), self.title, plainMessage];
		}

		UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, voiceOverAnnouncement);
	}
}

- (void) addMessage:(NSData *) messageData fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier {
	NSMutableDictionary *message = [[NSMutableDictionary alloc] init];

	if (messageData) message[@"message"] = messageData;
	if (user) message[@"user"] = user;
	if (identifier) message[@"identifier"] = identifier;
	message[@"action"] = @(action);

	[self addMessage:message];
}

- (void) addMessage:(NSDictionary *) message {
	NSParameterAssert(message != nil);

	CQProcessChatMessageOperation *operation = [[CQProcessChatMessageOperation alloc] initWithMessageInfo:message];
	operation.highlightNickname = self.connection.nickname;
	operation.encoding = self.encoding;
	operation.fallbackEncoding = self.connection.encoding;
	operation.ignoreController = self.connection.ignoreController;

	operation.target = self;
	operation.action = @selector(_messageProcessed:);

	[[CQDirectChatController chatMessageProcessingQueue] addOperation:operation];
}

#pragma mark -

- (void) _insertTimestamp {
	if (!timestampInterval || timestampEveryMessage) return;

	NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];

	if (!_lastTimestampTime)
		_lastTimestampTime = currentTime;

	if ((currentTime - _lastTimestampTime) <= timestampInterval)
		return;

	NSString *timestamp = nil;
	if (timestampFormat.length)
		timestamp = [NSDate formattedStringWithDate:[NSDate date] dateFormat:timestampFormat];
	else timestamp = [NSDate formattedShortTimeStringForDate:[NSDate date]];
	timestamp = [timestamp stringByEncodingXMLSpecialCharactersAsEntities];

	[self addEventMessage:timestamp withIdentifier:@"" announceWithVoiceOver:NO];

	_lastTimestampTime = currentTime;
}

#pragma mark -

- (void) actionSheet:(CQActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (buttonIndex == actionSheet.cancelButtonIndex)
		return;

	if (actionSheet.tag == InfoActionSheet) {
		if (buttonIndex == 0)
			[self showUserInformation];
	} else if (actionSheet.tag == URLActionSheet) {
		Class <CQBookmarking> bookmarkingService = [CQBookmarkingController activeService];
		NSURL *url = [actionSheet associatedObjectForKey:@"URL"];

		if (buttonIndex == 0)
			[[CQColloquyApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
		else if (bookmarkingService && buttonIndex == 1)
			[bookmarkingService bookmarkLink:url.absoluteString];
		else if ((!bookmarkingService && buttonIndex == 1) || (bookmarkingService && buttonIndex == 2))
			[[UIPasteboard generalPasteboard] setURL:url];
	}
}

#pragma mark -

- (void) _showActivityViewControllerWithItems:(NSArray *) items activities:(NSArray <UIActivity *> *) activities {
#if !SYSTEM(TV)
	_showingActivityViewController = YES;

	UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:activities];
	BOOL inputBarWasFirstResponder = [chatInputBar isFirstResponder];

	[self becomeFirstResponder];

	__weak __typeof__((self)) weakSelf = self;
	activityController.completionWithItemsHandler = ^(NSString *activityType, BOOL completed, NSArray <UIActivity *> *returnedItems, NSError *activityError) {
		__strong __typeof__((weakSelf)) strongSelf = weakSelf;
		[strongSelf _endShowingActivityViewControllerWithInputBarAsResponder:inputBarWasFirstResponder];
		[strongSelf.activityController dismissViewControllerAnimated:YES completion:^{
			strongSelf.activityController = nil;
		}];
	};

	activityController.modalPresentationStyle = UIModalPresentationPopover;
	activityController.popoverPresentationController.sourceView = chatInputBar.accessoryButton;
	activityController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;

	id old = self.activityController;
	if (old && [old isBeingPresented]) {
		[old dismissViewControllerAnimated:NO completion:^{
			__strong __typeof__((weakSelf)) strongSelf = weakSelf;
			[strongSelf presentViewController:activityController animated:YES completion:nil];
		}];
	} else [self presentViewController:activityController animated:YES completion:nil];
	self.activityController = activityController;
#endif
}

- (void) _endShowingActivityViewControllerWithInputBarAsResponder:(BOOL) inputBarAsResponder {
	[self resignFirstResponder];

	_showingActivityViewController = NO;

	if (inputBarAsResponder)
		[chatInputBar becomeFirstResponder];
	else [transcriptView becomeFirstResponder];
}

#pragma mark -

- (void) _showChatCreationViewController {
	CQChatCreationViewController *creationViewController = [[CQChatCreationViewController alloc] init];
	creationViewController.roomTarget = YES;
	creationViewController.selectedConnection = self.connection;

	[self _forceResignKeyboard];

	[[CQColloquyApplication sharedApplication] presentModalViewController:creationViewController animated:YES];
}

#pragma mark -

- (void) _showUserInfoControllerForUserNamed:(NSString *) nickname {
	[self _showUserInfoControllerForUser:[[self.connection chatUsersWithNickname:nickname] anyObject]];
}

- (void) _showUserInfoControllerForUser:(MVChatUser *) user {
	CQUserInfoController *userInfoController = [[CQUserInfoController alloc] init];
	userInfoController.user = user;

	[self _forceResignKeyboard];

	[[CQColloquyApplication sharedApplication] presentModalViewController:userInfoController animated:YES];
}

#pragma mark -

- (void) _showChatCompletions {
	NSRange possibleRange = [chatInputBar.textView.text rangeOfString:@" " options:NSBackwardsSearch range:NSMakeRange(0, chatInputBar.caretRange.location)];
	NSString *lastWord = nil;
	if (possibleRange.location != NSNotFound) {
		lastWord = [chatInputBar.textView.text substringFromIndex:possibleRange.location];

		possibleRange = NSMakeRange(possibleRange.location - possibleRange.length, possibleRange.length);
	} else {
		lastWord = chatInputBar.textView.text;

		possibleRange = NSMakeRange(0, lastWord.length);
	}

	[chatInputBar showCompletionsForText:lastWord inRange:possibleRange];
}

#pragma mark -

- (void) _forceResignKeyboard {
	_allowEditingToEnd = YES;
	[chatInputBar resignFirstResponder];
	_allowEditingToEnd = NO;
}

- (void) _showCantSendMessagesWarningForCommand:(BOOL) command {
	UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:@"" preferredStyle:UIAlertControllerStyleAlert];

	[alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title") style:UIAlertActionStyleCancel handler:nil]];

	if (command) alertController.title = NSLocalizedString(@"Can't Send Command", @"Can't send command alert title");
	else alertController.title = NSLocalizedString(@"Can't Send Message", @"Can't send message alert title");

	if (self.connection.status == MVChatConnectionConnectingStatus) {
		alertController.message = NSLocalizedString(@"You are currently connecting,\ntry sending again soon.", @"Can't send message to user because server is connecting alert message");
	} else if (!self.connection.connected) {
		alertController.message = NSLocalizedString(@"You are currently disconnected,\nreconnect and try again.", @"Can't send message to user because server is disconnected alert message");
		[alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Connect", @"Connect button title") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			[self.connection connectAppropriately];
		}]];
	} else if (self.user.status != MVChatUserAvailableStatus && self.user.status != MVChatUserAwayStatus) {
		alertController.message = NSLocalizedString(@"The user is not connected.", @"Can't send message to user because they are disconnected alert message");
	} else {
		return;
	}

	[self presentViewController:alertController animated:YES completion:nil];
}

- (void) _userDefaultsChanged {
	if (![NSThread isMainThread])
		return;

	if (self.user)
		_encoding = [[CQSettingsController settingsController] integerForKey:@"CQDirectChatEncoding"];

	NSString *chatTranscriptFontSizeString = [[CQSettingsController settingsController] stringForKey:@"CQChatTranscriptFontSize"];
	NSUInteger chatTranscriptFontSize = [UIFont preferredFontForTextStyle:UIFontTextStyleBody].pointSize;

	const CGFloat CQDefaultDynamicTypeFontSize = 17.;

	if (chatTranscriptFontSize == CQDefaultDynamicTypeFontSize || [[NSUserDefaults standardUserDefaults] boolForKey:@"CQOverrideDynamicTypeSize"]) {
		if (self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassRegular) {
			if (!chatTranscriptFontSizeString.length) {
				chatTranscriptFontSize = 14; // default
			} else if ([chatTranscriptFontSizeString isEqualToString:@"smallest"])
				chatTranscriptFontSize = 8;
			else if ([chatTranscriptFontSizeString isEqualToString:@"smaller"])
				chatTranscriptFontSize = 10;
			else if ([chatTranscriptFontSizeString isEqualToString:@"small"])
				chatTranscriptFontSize = 12;
			else if ([chatTranscriptFontSizeString isEqualToString:@"large"])
				chatTranscriptFontSize = 16;
			else if ([chatTranscriptFontSizeString isEqualToString:@"larger"])
				chatTranscriptFontSize = 18;
			else if ([chatTranscriptFontSizeString isEqualToString:@"largest"])
				chatTranscriptFontSize = 20;
		} else {
			if (!chatTranscriptFontSizeString.length) {
				chatTranscriptFontSize = 14; // default
			} else if ([chatTranscriptFontSizeString isEqualToString:@"smallest"])
				chatTranscriptFontSize = 11;
			else if ([chatTranscriptFontSizeString isEqualToString:@"smaller"])
				chatTranscriptFontSize = 12;
			else if ([chatTranscriptFontSizeString isEqualToString:@"small"])
				chatTranscriptFontSize = 13;
			else if ([chatTranscriptFontSizeString isEqualToString:@"large"])
				chatTranscriptFontSize = 15;
			else if ([chatTranscriptFontSizeString isEqualToString:@"larger"])
				chatTranscriptFontSize = 16;
			else if ([chatTranscriptFontSizeString isEqualToString:@"largest"])
				chatTranscriptFontSize = 17;
		}
	}

	transcriptView.styleIdentifier = [[CQSettingsController settingsController] stringForKey:@"CQChatTranscriptStyle"];
	transcriptView.fontFamily = [[CQSettingsController settingsController] stringForKey:@"CQChatTranscriptFont"];
	transcriptView.fontSize = chatTranscriptFontSize;
	transcriptView.timestampPosition = timestampEveryMessage ? (timestampOnLeft ? CQTimestampPositionLeft : CQTimestampPositionRight) : CQTimestampPositionCenter;
	transcriptView.allowSingleSwipeGesture = (![[UIDevice currentDevice] isPadModel] && !(self.splitViewController.displayMode == UISplitViewControllerDisplayModePrimaryHidden || self.splitViewController.displayMode == UISplitViewControllerDisplayModePrimaryOverlay));

	chatInputBar.font = [chatInputBar.font fontWithSize:chatTranscriptFontSize];
	if ([self isViewLoaded] && transcriptView)
		self.view.backgroundColor = transcriptView.backgroundColor;

	NSString *completionBehavior = [[CQSettingsController settingsController] stringForKey:@"CQChatAutocompleteBehavior"];
	chatInputBar.autocomplete = ![completionBehavior isEqualToString:@"Disabled"];
	chatInputBar.spaceCyclesCompletions = [completionBehavior isEqualToString:@"Keyboard"];

	BOOL autocorrect = ![[CQSettingsController settingsController] boolForKey:@"CQDisableChatAutocorrection"];
	chatInputBar.autocorrect = autocorrect;
	chatInputBar.tintColor = [CQColloquyApplication sharedApplication].tintColor;

	id capitalizationBehavior = [[CQSettingsController settingsController] objectForKey:@"CQChatAutocapitalizationBehavior"];
	if ([capitalizationBehavior isKindOfClass:[NSNumber class]])
		chatInputBar.autocapitalizationType = ([capitalizationBehavior boolValue] ? UITextAutocapitalizationTypeSentences : UITextAutocapitalizationTypeNone);
	else chatInputBar.autocapitalizationType = ([capitalizationBehavior isEqualToString:@"Sentences"] ? UITextAutocapitalizationTypeSentences : UITextAutocapitalizationTypeNone);
}

- (void) _nicknameDidChange:(NSNotification *) notification {
	MVChatUser *user = (MVChatUser *)notification.object;

	if (![user.connection isEqual:[_target connection]])
		return;

	[transcriptView noteNicknameChangedFrom:notification.userInfo[@"oldNickname"] to:user.nickname];

	if (_target == user)
		self.title = user.nickname;
}

- (void) _userNicknameDidChange:(NSNotification *) notification {
	if (!_watchRule)
		return;

	[self.connection removeChatUserWatchRule:_watchRule];

	_watchRule.nickname = self.user.nickname;

	[self.connection addChatUserWatchRule:_watchRule];
}

- (void) _willTerminate {
	[_target persistLastActivityDate];
}

- (void) _resignActive {
	[_target persistLastActivityDate];
}

- (void) _didEnterBackground {
	[self markScrollback];
}

- (void) _willEnterForeground {
	[self _addPendingComponentsAnimated:NO];
}

- (void) _willBecomeActive {
	[self _addPendingComponentsAnimated:NO];

	[self markAsRead];

	[[NSNotificationCenter chatCenter] postNotificationName:CQChatViewControllerUnreadMessagesUpdatedNotification object:self];
}

- (void) _willConnect:(NSNotification *) notification {
	if (clearOnConnect)
		[self clearController];
}

- (void) _didConnect:(NSNotification *) notification {
	[self addEventMessage:NSLocalizedString(@"Connected to the server.", "Connected to server event message") withIdentifier:@"reconnected"];

	[self _updateRightBarButtonItemAnimated:YES];
}

- (void) _didDisconnect:(NSNotification *) notification {
	[self addEventMessage:NSLocalizedString(@"Disconnected from the server.", "Disconnect from the server event message") withIdentifier:@"disconnected"];

	[self _updateRightBarButtonItemAnimated:YES];

	if (_active)
		[_target setMostRecentUserActivity:[NSDate date]];
}

- (void) _didRecieveDeviceToken:(NSNotification *) notification {
	if (_showDeviceTokenWhenRegistered)
		[self handleTokenCommandWithArguments:nil];
}

- (void) _awayStatusChanged:(NSNotification *) notification {
	if (self.connection.awayStatusMessage.length) {
		NSString *eventMessageFormat = [NSLocalizedString(@"You have set yourself as away with the message \"%@\".", "Marked as away event message") stringByEncodingXMLSpecialCharactersAsEntities];
		[self addEventMessageAsHTML:[NSString stringWithFormat:eventMessageFormat, MVChatStringAsString(self.connection.awayStatusMessage)] withIdentifier:@"awaySet"];
	} else {
		[self addEventMessage:NSLocalizedString(@"You have returned from being away.", "Returned from being away event message") withIdentifier:@"awayRemoved"];
	}
}

- (void) _updateRightBarButtonItemAnimated:(BOOL) animated {
	if (!self.user)
		return;

	UIBarButtonItem *item = nil;

	if (self.connection.connected) {
		item = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed: @"infoButton.png"] style:UIBarButtonItemStylePlain target:self action:@selector(showUserInformation)];
		item.accessibilityLabel = NSLocalizedString(@"User Information", @"Voiceover user information label"); 
	} else {
		item = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Connect", "Connect button title") style:UIBarButtonItemStyleDone target:self.connection action:@selector(connect)];
		item.accessibilityLabel = NSLocalizedString(@"Connect to Server", @"Voiceover connect to server label");
	}

	[self.navigationItem setRightBarButtonItem:item animated:animated];

	if (_active)
		[[CQChatController defaultController].chatPresentationController updateToolbarAnimated:YES];

}

- (NSString *) _localNotificationTitleForMessage:(NSDictionary *) message {
	MVChatUser *user = message[@"user"];
	return user.connection.displayName;
}

- (NSString *) _localNotificationBodyForMessage:(NSDictionary *) message {
	MVChatUser *user = message[@"user"];
	NSString *messageText = message[@"messagePlain"];
	if ([message[@"action"] boolValue])
		return [NSString stringWithFormat:@"%@ %@", user.displayName, messageText];
	return [NSString stringWithFormat:@"%@ \u2014 %@", user.displayName, messageText];
}

- (NSDictionary *) _localNotificationUserInfoForMessage:(NSDictionary *) message {
	MVChatUser *user = message[@"user"];
	return @{@"c": user.connection.uniqueIdentifier, @"n": user.nickname};
}

- (void) _showLocalNotificationForMessage:(NSDictionary *) message withSoundName:(NSString *__nullable) soundName {
	if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground)
		return;

#if !SYSTEM(TV)
	UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
	content.threadIdentifier = @"Global";
	content.userInfo = [self _localNotificationUserInfoForMessage:message];
	content.body = [self _localNotificationBodyForMessage:message];
	content.title = [self _localNotificationTitleForMessage:message];
	content.sound = [UNNotificationSound soundNamed:soundName];

	UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:@"multitasking" content:content trigger:nil];
	[[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
#endif
}

- (void) _processMessageData:(NSData *) messageData target:(id) target action:(SEL) action userInfo:(id) userInfo {
	CQProcessChatMessageOperation *operation = [[CQProcessChatMessageOperation alloc] initWithMessageData:messageData];
	operation.highlightNickname = self.connection.nickname;
	operation.encoding = self.encoding;
	operation.fallbackEncoding = self.connection.encoding;

	operation.target = target;
	operation.action = action;

	operation.userInfo = userInfo;

	if (!messageData) {
		if (target && action)
			[target performSelectorOnMainThread:action withObject:operation waitUntilDone:NO];
		return;
	}

	[[CQDirectChatController chatMessageProcessingQueue] addOperation:operation];

}

- (void) _batchUpdatesWillBegin:(NSNotification *) notification {
	NSString *type = notification.userInfo[@"type"];
	NSString *identifier = notification.userInfo[@"identifier"];

	if ([type isCaseInsensitiveEqualToString:@"znc.in/playback"] || [type hasCaseInsensitiveSubstring:@"playback"]) {
		_coalescePendingUpdates = YES;

		NSMutableArray *associatedBatches = _batchTypeAssociation[@(CQBatchTypeBuffer)];
		if (!associatedBatches)
			_batchTypeAssociation[@(CQBatchTypeBuffer)] = [NSMutableArray array];
		[associatedBatches addObject:identifier];

	} // don't do anything on unknown batch types
}

- (void) _batchUpdatesDidEnd:(NSNotification *) notification {
	NSString *type = notification.userInfo[@"type"];
	NSString *identifier = notification.userInfo[@"identifier"];

	if ([type isCaseInsensitiveEqualToString:@"znc.in/playback"] || [type hasCaseInsensitiveSubstring:@"playback"]) {
		NSMutableArray *associatedBatches = _batchTypeAssociation[@(CQBatchTypeBuffer)];
		[associatedBatches removeObject:identifier];
		if (associatedBatches.count == 0) {
			[_batchTypeAssociation removeObjectForKey:@(CQBatchTypeBuffer)];
			_coalescePendingUpdates = NO;

			[self _addPendingComponentsAnimated:YES];
		}
	} // don't do anything on unknown batch types
}

- (void) _addPendingComponent:(id) component {
	if (!_pendingComponents)
		_pendingComponents = [[NSMutableArray alloc] init];

	BOOL hadPendingComponents = _pendingComponents.count;

	[_pendingComponents addObject:component];

	while (_pendingComponents.count > scrollbackLength)
		[_pendingComponents removeObjectAtIndex:0];

	BOOL active = _active;
	active &= ([UIApplication sharedApplication].applicationState == UIApplicationStateActive);

	if (!transcriptView || !active || _coalescePendingUpdates)
		return;

	if (!hadPendingComponents) {
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_addPendingComponents) object:nil];

		[self performSelector:@selector(_addPendingComponents) withObject:nil afterDelay:0.1];
	}
}

- (void) _addPendingComponents {
	[self _addPendingComponentsAnimated:YES];
}

- (void) _addPendingComponentsAnimated:(BOOL) animated {
	if (!_pendingComponents.count || _coalescePendingUpdates)
		return;

	[transcriptView addComponents:_pendingComponents animated:animated];

	[_pendingComponents removeAllObjects];
}

- (BOOL) canAnnounceWithVoiceOverAndMessageIsImportant:(BOOL) important {
	id visibleChatController = [CQChatController defaultController].visibleChatController;
	if (!important && visibleChatController && visibleChatController != self)
		return NO;
	return UIAccessibilityIsVoiceOverRunning();
}

- (void) _messageProcessed:(CQProcessChatMessageOperation *) operation {
	NSMutableDictionary *message = operation.processedMessageInfo;
	if (!message) return;
	BOOL highlighted = [message[@"highlighted"] boolValue];
	BOOL notice = [message[@"notice"] boolValue];
	BOOL action = [message[@"action"] boolValue];

	BOOL active = _active;
	active &= ([UIApplication sharedApplication].applicationState == UIApplicationStateActive);

	MVChatUser *user = message[@"user"];
	if (!user.localUser && !active && self.available) {
		if (highlighted) ++_unreadHighlightedMessages;
		else ++_unreadMessages;

		[[NSNotificationCenter chatCenter] postNotificationName:CQChatViewControllerUnreadMessagesUpdatedNotification object:self];

		if (self.user || highlighted)
			++[CQChatController defaultController].totalImportantUnreadCount;
	}

	if (user.isLocalUser)
		self.mostRecentOutgoingMessageTimestamp = message[@"time"] ?: [NSDate date];
	else self.mostRecentIncomingMessageTimestamp = message[@"time"] ?: [NSDate date];

	[[NSNotificationCenter chatCenter] postNotificationName:CQChatViewControllerHandledMessageNotification object:self];

	NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];

	BOOL directChat = [self isMemberOfClass:[CQDirectChatController class]];
	BOOL privateAlertsAllowed = (!privateMessageAlertTimeout || (currentTime - _lastMessageTime) >= privateMessageAlertTimeout);
	BOOL vibrated = NO;
	BOOL playedSound = NO;
	BOOL showedAlert = NO;

	_lastMessageTime = currentTime;

	if (!user.localUser && directChat && privateAlertsAllowed) {
		if (vibrateOnPrivateMessage && !vibrated) {
			[CQSoundController vibrate];
			vibrated = YES;
		}

		if (privateMessageSound && !playedSound) {
			[privateMessageSound playSound];
			playedSound = YES;
		}

		if (localNotificationOnPrivateMessage && !showedAlert) {
			[self _showLocalNotificationForMessage:message withSoundName:privateMessageSound.soundName];
			showedAlert = YES;
		}
	}

	if (highlighted && self.available) {
		if (vibrateOnHighlight && !vibrated)
			[CQSoundController vibrate];

		if (highlightSound && !playedSound)
			[highlightSound playSound];

		if (localNotificationOnHighlight && !showedAlert)
			[self _showLocalNotificationForMessage:message withSoundName:highlightSound.soundName];
	}

	if (!user.localUser && [self canAnnounceWithVoiceOverAndMessageIsImportant:(directChat || highlighted)]) {
		NSString *voiceOverAnnouncement = nil;

		if (action) {
			if (directChat && highlighted)
				voiceOverAnnouncement = [[NSString alloc] initWithFormat:NSLocalizedString(@"%@ highlighted you, privately %@", @"VoiceOver notice announcement when highlighted in a direct chat"), user.displayName, operation.processedMessageAsPlainText];
			else if (directChat || notice)
				voiceOverAnnouncement = [[NSString alloc] initWithFormat:NSLocalizedString(@"%@ privately %@", @"VoiceOver notice announcement when in a direct chat"), user.displayName, operation.processedMessageAsPlainText];
			else if (highlighted)
				voiceOverAnnouncement = [[NSString alloc] initWithFormat:NSLocalizedString(@"%@ highlighted you in %@, %@", @"VoiceOver notice announcement when highlighted in a chat room"), user.displayName, self.title, operation.processedMessageAsPlainText];
			else voiceOverAnnouncement = [[NSString alloc] initWithFormat:NSLocalizedString(@"%@ in %@ %@", @"VoiceOver notice announcement when in a chat room"), user.displayName, self.title, operation.processedMessageAsPlainText];
		} else {
			if (directChat && highlighted)
				voiceOverAnnouncement = [[NSString alloc] initWithFormat:NSLocalizedString(@"%@ highlighted you, privately saying: %@", @"VoiceOver announcement when highlighted in a direct chat"), user.displayName, operation.processedMessageAsPlainText];
			else if (directChat || notice)
				voiceOverAnnouncement = [[NSString alloc] initWithFormat:NSLocalizedString(@"%@ privately said: %@", @"VoiceOver announcement when in a direct chat"), user.displayName, operation.processedMessageAsPlainText];
			else if (highlighted)
				voiceOverAnnouncement = [[NSString alloc] initWithFormat:NSLocalizedString(@"%@ highlighted you in %@, saying: %@", @"VoiceOver announcement when highlighted in a chat room"), user.displayName, self.title, operation.processedMessageAsPlainText];
			else voiceOverAnnouncement = [[NSString alloc] initWithFormat:NSLocalizedString(@"%@ in %@ said: %@", @"VoiceOver announcement when in a chat room"), user.displayName, self.title, operation.processedMessageAsPlainText];
		}

		UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, voiceOverAnnouncement);
	}

	if (!_recentMessages)
		_recentMessages = [[NSMutableArray alloc] init];
	[_recentMessages addObject:message];

	while (_recentMessages.count > 10)
		[_recentMessages removeObjectAtIndex:0];

	[self _insertTimestamp];

	[self _addPendingComponent:message];

	if (!user.localUser)
		[[NSNotificationCenter chatCenter] postNotificationName:CQChatViewControllerRecentMessagesUpdatedNotification object:self];
}
@end

NS_ASSUME_NONNULL_END
