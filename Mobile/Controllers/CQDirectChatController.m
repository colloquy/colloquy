#import "CQDirectChatController.h"

#import "CQAlertView.h"
#import "CQChatController.h"
#import "CQChatOrderingController.h"
#import "CQChatCreationViewController.h"
#import "CQChatInputBar.h"
#import "CQChatInputStyleViewController.h"
#import "CQChatPresentationController.h"
#import "CQChatRoomController.h"
#import "CQChatTableCell.h"
#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"
#import "CQIgnoreRulesController.h"
#import "CQIntroductoryGIFFrameOperation.h"
#import "CQPreferencesListViewController.h"
#import "CQProcessChatMessageOperation.h"
#import "CQSoundController.h"
#import "CQImportantChatMessageViewController.h"
#import "CQUserInfoController.h"
#import "CQDeliciousController.h"
#import "CQInstapaperController.h"
#import "CQPinboardController.h"
#import "CQPocketController.h"

#import "KAIgnoreRule.h"

#import "NSDateAdditions.h"
#import "NSObjectAdditions.h"
#import "NSStringAdditions.h"

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatUser.h>
#import <ChatCore/MVChatUserWatchRule.h>

#import <MediaPlayer/MPMusicPlayerController.h>
#import <MediaPlayer/MPMediaItem.h>

#import <Social/Social.h>

#import <objc/message.h>

#define InfoActionSheet 1001
#define ActionsActionSheet 1002
#define URLActionSheet 1003

#define CantSendMessageAlertView 100
#define BookmarkLogInAlertView 101

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

@implementation CQDirectChatController
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

		[[NSNotificationCenter defaultCenter] postNotificationName:CQScrollbackLengthDidChangeNotification object:nil];
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
			CQAlertView *alertView = [[CQAlertView alloc] init];
			alertView.delegate = self;
			alertView.tag = BookmarkLogInAlertView;
			alertView.title = [activeService serviceName];

			[alertView addTextFieldWithPlaceholder:NSLocalizedString(@"Username or Email", @"Username or Email placeholder") andText:@""];
			[alertView addSecureTextFieldWithPlaceholder:NSLocalizedString(@"Password", @"Password placeholder")];

			[alertView addButtonWithTitle:NSLocalizedString(@"Log In", @"Log In button")];
			alertView.cancelButtonIndex = [alertView addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button")];

			[alertView associateObject:notification.object forKey:@"link"];

			[alertView show];
		}
	} else if (error.code == CQBookmarkingErrorServer) {
		UIAlertView *alertView = [[CQAlertView alloc] init];
		alertView.title = NSLocalizedString(@"Server Error", @"Server Error");
		alertView.message = [NSString stringWithFormat:NSLocalizedString(@"Unable to save \"%@\" to %@ due to a server error.", @"Unable to bookmark link server error message"), notification.object, [activeService serviceName]];
		alertView.cancelButtonIndex = [alertView addButtonWithTitle:NSLocalizedString(@"Okay", @"Okay button")];
		[alertView show];
	} else {
		UIAlertView *alertView = [[CQAlertView alloc] init];
		alertView.title = NSLocalizedString(@"Unknown Error", @"Unknown Error");
		alertView.message = [NSString stringWithFormat:NSLocalizedString(@"Unable to save \"%@\" to %@.", @"Unable to bookmark link message"), notification.object, [activeService serviceName]];
		alertView.cancelButtonIndex = [alertView addButtonWithTitle:NSLocalizedString(@"Okay", @"Okay button")];
		[alertView show];
	}
}

+ (void) initialize {
	static BOOL userDefaultsInitialized;

	if (userDefaultsInitialized)
		return;

	userDefaultsInitialized = YES;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDefaultsChanged) name:CQSettingsDidChangeNotification object:nil];

	[self userDefaultsChanged];

	if ([[UIDevice currentDevice] isPadModel]) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow) name:UIKeyboardWillShowNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide) name:UIKeyboardWillHideNotification object:nil];
	}
}

+ (void) keyboardWillShow {
	showingKeyboard = YES;
}

+ (void) keyboardWillHide {
	showingKeyboard = NO;
}

+ (NSOperationQueue *) chatMessageProcessingQueue {
	if (!chatMessageProcessingQueue) {
		chatMessageProcessingQueue = [[NSOperationQueue alloc] init];
		chatMessageProcessingQueue.maxConcurrentOperationCount = 1;
	}

	return chatMessageProcessingQueue;
}

- (id) initWithTarget:(id) target {
	if (!(self = [super initWithNibName:@"CQUIChatView" bundle:nil]))
		return nil;

	_target = target;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_awayStatusChanged:) name:MVChatConnectionSelfAwayStatusChangedNotification object:self.connection];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_willConnect:) name:MVChatConnectionWillConnectNotification object:self.connection];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didConnect:) name:MVChatConnectionDidConnectNotification object:self.connection];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didDisconnect:) name:MVChatConnectionDidDisconnectNotification object:self.connection];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didRecieveDeviceToken:) name:CQColloquyApplicationDidRecieveDeviceTokenNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_userDefaultsChanged) name:CQSettingsDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_userDefaultsChanged) name:UIContentSizeCategoryDidChangeNotification object:nil];

	if ([[UIDevice currentDevice] isPadModel]) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

		_showingKeyboard = showingKeyboard;
	}

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_nicknameDidChange:) name:MVChatUserNicknameChangedNotification object:nil];

	if (self.user) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_userNicknameDidChange:) name:MVChatUserNicknameChangedNotification object:self.user];

		_encoding = [[CQSettingsController settingsController] integerForKey:@"CQDirectChatEncoding"];

		_watchRule = [[MVChatUserWatchRule alloc] init];
		_watchRule.nickname = self.user.nickname;

		[self.connection addChatUserWatchRule:_watchRule];

		_revealKeyboard = YES;
	}

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scrollbackLengthDidChange:) name:CQScrollbackLengthDidChangeNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_batchUpdatesWillBegin:) name:MVChatConnectionBatchUpdatesWillBeginNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_batchUpdatesDidEnd:) name:MVChatConnectionBatchUpdatesDidEndNotification object:nil];

	[self setScrollbackLength:scrollbackLength];

	_sentMessages = [[NSMutableArray alloc] init];
	_batchStorage = [NSMutableDictionary dictionary];
	_batchTypeAssociation = [NSMutableDictionary dictionary];

	return self;
}

- (id) initWithPersistentState:(NSDictionary *) state usingConnection:(MVChatConnection *) connection {
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

	_revealKeyboard = NO;

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
	return [UIImage imageNamed:@"directChatIcon.png"];
}

- (void) setTitle:(NSString *) title {
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
		return nil;

	NSMutableDictionary *state = [[NSMutableDictionary alloc] init];

	state[@"class"] = NSStringFromClass([self class]);

	if ([CQChatController defaultController].visibleChatController == self)
		state[@"active"] = @YES;

	if (self.user)
		state[@"user"] = self.user.nickname;

	NSMutableArray *messages = [[NSMutableArray alloc] init];

	for (NSDictionary *message in _recentMessages) {
		static NSArray *sameKeys = nil;
		if (!sameKeys)
			sameKeys = @[@"message", @"messagePlain", @"action", @"notice", @"highlighted", @"identifier", @"type"];

		NSMutableDictionary *newMessage = [[NSMutableDictionary alloc] initWithKeys:sameKeys fromDictionary:message];

		if ([newMessage[@"message"] isEqual:newMessage[@"messagePlain"]])
			[newMessage removeObjectForKey:@"messagePlain"];

		MVChatUser *user = message[@"user"];
		if (user && !user.localUser) newMessage[@"user"] = user.nickname;
		else if (user.localUser) newMessage[@"localUser"] = @YES;

		[messages addObject:newMessage];
	}

	if (messages.count)
		state[@"messages"] = messages;

	return state;
}

#pragma mark -

- (UIActionSheet *) actionSheet {
	UIActionSheet *sheet = [[UIActionSheet alloc] init];
	sheet.delegate = self;
	sheet.tag = InfoActionSheet;

	if (!([[UIDevice currentDevice] isPadModel] && UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation)))
		sheet.title = self.user.displayName;

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

- (void) showRecentlySentMessages {
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

- (NSArray *) keyCommands {
	static NSArray *keyCommands = nil;
	if (!keyCommands) {
		UIKeyCommand *altTabKeyCommand = [UIKeyCommand keyCommandWithInput:@"\t" modifierFlags:UIKeyModifierAlternate action:@selector(_handleKeyCommand:)];
		UIKeyCommand *shiftAltTabKeyCommand = [UIKeyCommand keyCommandWithInput:@"\t" modifierFlags:(UIKeyModifierAlternate | UIKeyModifierShift) action:@selector(_handleKeyCommand:)];
		UIKeyCommand *cmdUpKeyCommand = [UIKeyCommand keyCommandWithInput:UIKeyInputUpArrow modifierFlags:UIKeyModifierCommand action:@selector(_handleKeyCommand:)];
		UIKeyCommand *cmdDownKeyCommand = [UIKeyCommand keyCommandWithInput:UIKeyInputDownArrow modifierFlags:UIKeyModifierCommand action:@selector(_handleKeyCommand:)];
		UIKeyCommand *optCmdUpKeyCommand = [UIKeyCommand keyCommandWithInput:UIKeyInputUpArrow modifierFlags:(UIKeyModifierCommand | UIKeyModifierAlternate) action:@selector(_handleKeyCommand:)];
		UIKeyCommand *optCmdDownKeyCommand = [UIKeyCommand keyCommandWithInput:UIKeyInputDownArrow modifierFlags:(UIKeyModifierCommand | UIKeyModifierAlternate) action:@selector(_handleKeyCommand:)];

		keyCommands = @[altTabKeyCommand, shiftAltTabKeyCommand, cmdUpKeyCommand, cmdDownKeyCommand, optCmdUpKeyCommand, optCmdDownKeyCommand];
	}
	return keyCommands;
}

- (UIScrollView *) scrollView {
	return transcriptView.scrollView;
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	// while CQWKChatView exists and is ready to be used (for the most part), WKWebView does not support being loaded from a xib yet
	if ([UIDevice currentDevice].isSystemEight) {
		CQWKChatTranscriptView *webkitChatTranscriptView = [[CQWKChatTranscriptView alloc] initWithFrame:transcriptView.frame];
		webkitChatTranscriptView.autoresizingMask = transcriptView.autoresizingMask;
		webkitChatTranscriptView.transcriptDelegate = self;

		[transcriptView.superview insertSubview:webkitChatTranscriptView aboveSubview:transcriptView];

		[transcriptView removeFromSuperview];
		transcriptView = webkitChatTranscriptView;
	}

	[self _updateRightBarButtonItemAnimated:NO];

	chatInputBar.accessibilityLabel = NSLocalizedString(@"Enter chat message.", @"Voiceover enter chat message label");
	chatInputBar.accessibilityTraits = UIAccessibilityTraitUpdatesFrequently;

	[self _userDefaultsChanged];

	transcriptView.allowSingleSwipeGesture = ([UIDevice currentDevice].isPhoneModel || ![[CQColloquyApplication sharedApplication] splitViewController:nil shouldHideViewController:nil inOrientation:[UIApplication sharedApplication].statusBarOrientation]);
	[chatInputBar setAccessoryImage:[UIImage imageNamed:@"clear.png"] forResponderState:CQChatInputBarResponder controlState:UIControlStateNormal];
	[chatInputBar setAccessoryImage:[UIImage imageNamed:@"clearPressed.png"] forResponderState:CQChatInputBarResponder controlState:UIControlStateHighlighted];
	[chatInputBar setAccessoryImage:[UIImage imageNamed:@"infoButton.png"] forResponderState:CQChatInputBarNotResponder controlState:UIControlStateNormal];
	[chatInputBar setAccessoryImage:[UIImage imageNamed:@"infoButtonPressed.png"] forResponderState:CQChatInputBarNotResponder controlState:UIControlStateHighlighted];
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	[self _addPendingComponentsAnimated:NO];

	if (![[UIDevice currentDevice] isPadModel]) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	}

	if (_showingKeyboard || showingKeyboard || hardwareKeyboard) {
		_revealKeyboard = YES;
	}

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didNotBookmarkLink:) name:CQBookmarkingDidNotSaveLinkNotification object:nil];

	if ([transcriptView.styleIdentifier hasCaseInsensitiveSuffix:@"-dark"])
		if ([self.navigationController.navigationBar respondsToSelector:@selector(setBarTintColor:)])
			self.navigationController.navigationBar.barTintColor = [[UIColor darkGrayColor] colorWithAlphaComponent:.9];
}

- (void) viewDidAppear:(BOOL) animated {
	[super viewDidAppear:animated];

	_active = YES;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_willEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_willBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];

	[self _addPendingComponentsAnimated:YES];

	[transcriptView performSelector:@selector(flashScrollIndicators) withObject:nil afterDelay:0.1];

	if (_unreadHighlightedMessages)
		[CQChatController defaultController].totalImportantUnreadCount -= _unreadHighlightedMessages;

	if (_unreadMessages && self.user)
		[CQChatController defaultController].totalImportantUnreadCount -= _unreadMessages;

	_unreadMessages = 0;
	_unreadHighlightedMessages = 0;

	[[NSNotificationCenter defaultCenter] postNotificationName:CQChatViewControllerUnreadMessagesUpdatedNotification object:self];

	if (_revealKeyboard) {
		_revealKeyboard = NO;
		[chatInputBar performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0.5];
	}
}

- (void) viewWillDisappear:(BOOL) animated {
	[super viewWillDisappear:animated];

	hardwareKeyboard = (!_showingKeyboard && [chatInputBar isFirstResponder]);
	[chatInputBar resignFirstResponder];

	[chatInputBar hideCompletions];

	_active = NO;
	_allowEditingToEnd = YES;

	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:CQBookmarkingDidNotSaveLinkNotification object:nil];

	if (![[UIDevice currentDevice] isPadModel]) {
		[self.view endEditing:YES];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
	}

	[super viewWillDisappear:animated];
}

- (void) viewDidDisappear:(BOOL) animated {
	[super viewDidDisappear:animated];

	if (![[UIDevice currentDevice] isPadModel])
		[chatInputBar resignFirstResponder];

	_allowEditingToEnd = NO;
}

- (void) viewWillLayoutSubviews {
	[super viewWillLayoutSubviews];

	[chatInputBar updateTextViewContentSize];
}

- (void) viewWillTransitionToSize:(CGSize) size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>) coordinator {
	BOOL isShowingCompletionsBeforeRotation = chatInputBar.isShowingCompletions;

//	transcriptView.allowSingleSwipeGesture = ([UIDevice currentDevice].isPhoneModel || ![[CQColloquyApplication sharedApplication] splitViewController:nil shouldHideViewController:nil inOrientation:toInterfaceOrientation]);

	[coordinator animateAlongsideTransition:^(id <UIViewControllerTransitionCoordinatorContext> context) {} completion:^(id <UIViewControllerTransitionCoordinatorContext> context) {
		[transcriptView scrollToBottomAnimated:NO];

		if (isShowingCompletionsBeforeRotation)
			[self _showChatCompletions];
	}];
}

#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_8_0
- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation) toInterfaceOrientation duration:(NSTimeInterval) duration {
	_isShowingCompletionsBeforeRotation = chatInputBar.isShowingCompletions;

	transcriptView.allowSingleSwipeGesture = ([UIDevice currentDevice].isPhoneModel || ![[CQColloquyApplication sharedApplication] splitViewController:nil shouldHideViewController:nil inOrientation:toInterfaceOrientation]);
}

- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation) fromInterfaceOrientation {
	[transcriptView scrollToBottomAnimated:NO];

	if (_isShowingCompletionsBeforeRotation) {
		[self _showChatCompletions];

		_isShowingCompletionsBeforeRotation = NO;
	}
}
#endif

#pragma mark -

- (void) chatInputBarAccessoryButtonPressed:(CQChatInputBar *) theChatInputBar {
	if ([theChatInputBar isFirstResponder] && theChatInputBar.textView.hasText) {
		theChatInputBar.textView.text = nil;

		// Work around behavior where textViewDidChange: isn't called when you change the text programatically.
		if ([theChatInputBar.textView.delegate respondsToSelector:@selector(textViewDidChange:)])
			[theChatInputBar.textView.delegate textViewDidChange:theChatInputBar.textView];

		[theChatInputBar hideCompletions];

		return;
	}

	UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
	actionSheet.delegate = self;
	actionSheet.tag = ActionsActionSheet;

	if (!([[UIDevice currentDevice] isPadModel] && UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation)))
		actionSheet.title = self.user.displayName;

	[actionSheet addButtonWithTitle:NSLocalizedString(@"Recently Sent Messages", @"Recently Sent Messages")];

	actionSheet.cancelButtonIndex = [actionSheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button title")];

	[[CQColloquyApplication sharedApplication] showActionSheet:actionSheet];
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

- (NSArray *) chatInputBar:(CQChatInputBar *) chatInputBar completionsForWordWithPrefix:(NSString *) word inRange:(NSRange) range {
	NSMutableArray *completions = [[NSMutableArray alloc] init];

	if (word.length >= 2) {
		NSString *nickname = (range.location ? self.user.nickname : [self.user.nickname stringByAppendingString:@":"]);
		if ([nickname hasCaseInsensitivePrefix:word] && ![nickname isEqualToString:word])
			[completions addObject:nickname];

		nickname = (range.location ? self.connection.nickname : [self.connection.nickname stringByAppendingString:@":"]);
		if ([nickname hasCaseInsensitivePrefix:word] && ![nickname isEqualToString:word])
			[completions addObject:nickname];

		static NSArray *services;
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
		static NSArray *commands;
		if (!commands) commands = @[@"/me", @"/msg", @"/nick", @"/join", @"/list", @"/away", @"/whois", @"/say", @"/raw", @"/quote", @"/quit", @"/disconnect", @"/query", @"/part", @"/notice", @"/onotice", @"/umode", @"/globops",
#if ENABLE(FILE_TRANSFERS)
		@"/dcc",
#endif
		@"/aaway", @"/anick", @"/aquit", @"/amsg", @"/ame", @"/google", @"/wikipedia", @"/amazon", @"/safari", @"/browser", @"/url", @"/clear", @"/nickserv", @"/chanserv", @"/help", @"/faq", @"/search", @"/ipod", @"/music", @"/squit", @"/welcome", @"/sysinfo", @"/ignore", @"/unignore"];

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

- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar sendText:(NSString *) text {
	_didSendRecently = YES;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(resetDidSendRecently) object:nil];
	[self performSelector:@selector(resetDidSendRecently) withObject:nil afterDelay:0.5];

	if (!_target)
		return YES;

	return [self _sendText:text];
}

- (BOOL) _sendText:(NSString *) text {
	BOOL didSendText = NO;
	for (__strong NSString *line in [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
		line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		if (line.length)
			didSendText = [self _sendLineOfText:line] || didSendText; // send text first to not short-circuit and stop
	}
	return didSendText;
}

- (BOOL ) _sendLineOfText:(NSString *) text {
	if ([text hasPrefix:@"/"] && ![text hasPrefix:@"//"] && text.length > 1) {
		static NSSet *commandsNotRequiringConnection;
		if (!commandsNotRequiringConnection)
			commandsNotRequiringConnection = [[NSSet alloc] initWithObjects:@"google", @"wikipedia", @"amazon", @"safari", @"browser", @"url", @"clear", @"help", @"faq", @"search", @"list", @"join", @"welcome", @"token", @"resetbadge", @"tweet", @"aquit", @"anick", @"aaway", nil];

		// Send as a command.
		NSScanner *scanner = [NSScanner scannerWithString:text];
		[scanner setCharactersToBeSkipped:nil];

		NSString *command = nil;
		NSString *arguments = nil;

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

		arguments = [text substringFromIndex:scanner.scanLocation];

		NSString *commandSelectorString = [NSString stringWithFormat:@"handle%@CommandWithArguments:", [command capitalizedString]];
		SEL commandSelector = NSSelectorFromString(commandSelectorString);

		BOOL handled = NO;
		if ([self respondsToSelector:commandSelector])
			handled = ((BOOL (*)(id, SEL, NSString *))objc_msgSend)(self, commandSelector, arguments);

		if (!handled) [_target sendCommand:command withArguments:arguments withEncoding:self.encoding];
	} else {
		if (!self.available) {
			[self _showCantSendMessagesWarningForCommand:NO];
			return NO;
		}

		// Send as a message, strip the first forward slash if it exists.
		if ([text hasPrefix:@"/"] && text.length > 1)
			text = [text substringFromIndex:1];

		__block BOOL action = NO;

		if (naturalChatActions && !action) {
			static NSSet *actionVerbs;
			if (!actionVerbs) {
				NSArray *verbs = [[NSArray alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"verbs" ofType:@"plist"]];
				actionVerbs = [[NSSet alloc] initWithArray:verbs];
			}

			NSScanner *scanner = [[NSScanner alloc] initWithString:text];
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

- (BOOL) chatInputBar:(CQChatInputBar *) theChatInputBar shouldChangeHeightBy:(CGFloat) difference {
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

#pragma mark -

- (void) importantChatMessageViewController:(CQImportantChatMessageViewController *) importantChatMessageViewController didSelectMessage:(NSString *) message isAction:(BOOL) isAction {
	[[CQColloquyApplication sharedApplication] dismissModalViewControllerAnimated:[UIView areAnimationsEnabled]];

	if (isAction)
		chatInputBar.textView.text = [@"/me " stringByAppendingString:message];
	else chatInputBar.textView.text = message;

	[chatInputBar becomeFirstResponder];
}

#pragma mark -

- (void) clearController {
	[_pendingComponents removeAllObjects];

	_pendingPreviousSessionComponents = nil;
	_recentMessages = nil;

	if (_unreadHighlightedMessages)
		[CQChatController defaultController].totalImportantUnreadCount -= _unreadHighlightedMessages;

	if (_unreadMessages && self.user)
		[CQChatController defaultController].totalImportantUnreadCount -= _unreadMessages;

	_unreadMessages = 0;
	_unreadHighlightedMessages = 0;

	[[NSNotificationCenter defaultCenter] postNotificationName:CQChatViewControllerUnreadMessagesUpdatedNotification object:self];

	[transcriptView reset];
}

#pragma mark -

- (void) markScrollback {
	if (!markScrollbackOnMultitasking)
		return;

	[transcriptView markScrollback];
}

#pragma mark -

- (BOOL) _openURL:(NSURL *) url {
	[self _forceRegsignKeyboard];

	return [[CQColloquyApplication sharedApplication] openURL:url];
}

- (BOOL) _handleURLCommandWithArguments:(NSString *) arguments {
	NSScanner *scanner = [NSScanner scannerWithString:arguments];
	NSString *urlString = nil;

	[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&urlString];

	if (!urlString.length)
		return NO;

	if ([arguments isCaseInsensitiveEqualToString:@"last"])
		urlString = @"about:last";

	NSURL *url = (urlString ? [NSURL URLWithString:urlString] : nil);
	if (urlString && !url.scheme.length) url = [NSURL URLWithString:[@"http://" stringByAppendingString:urlString]];

	[self _openURL:url];

	return YES;
}

- (BOOL) handleConsoleCommandWithArguments:(NSString *) arguments {
	if (arguments.length)
		[CQConnectionsController defaultController].shouldLogRawMessagesToConsole = [arguments isCaseInsensitiveEqualToString:@"on"];
	else [[CQChatController defaultController] showConsoleForConnection:self.connection];

	return YES;
}

- (BOOL) handleBrowserCommandWithArguments:(NSString *) arguments {
	return [self _handleURLCommandWithArguments:arguments];
}

- (BOOL) handleSafariCommandWithArguments:(NSString *) arguments {
	return [self _handleURLCommandWithArguments:arguments];
}

- (BOOL) handleUrlCommandWithArguments:(NSString *) arguments {
	return [self handleSafariCommandWithArguments:arguments];
}

- (BOOL) handleAquitCommandWithArguments:(NSString *) arguments {
	for (MVChatConnection *connection in [CQConnectionsController defaultController].connectedConnections)
		[connection disconnectWithReason:arguments];
	return YES;
}

- (BOOL) handleAawayCommandWithArguments:(NSString *) arguments {
	for (MVChatConnection *connection in [CQConnectionsController defaultController].connectedConnections)
		connection.awayStatusMessage = arguments;
	return YES;
}

- (BOOL) handleAnickCommandWithArguments:(NSString *) arguments {
	for (MVChatConnection *connection in [CQConnectionsController defaultController].connectedConnections)
		connection.nickname = arguments;
	return YES;
}

- (BOOL) handleAmsgCommandWithArguments:(NSString *) arguments {
	NSArray *rooms = [[CQChatOrderingController defaultController] chatViewControllersOfClass:[CQChatRoomController class]];
	for (CQChatRoomController *controller in rooms) {
		if (!controller.connection.connected)
			continue;
		[controller sendMessage:arguments asAction:NO];
	}

	return YES;
}

- (BOOL) handleAmeCommandWithArguments:(NSString *) arguments {
	NSArray *rooms = [[CQChatOrderingController defaultController] chatViewControllersOfClass:[CQChatRoomController class]];
	for (CQChatRoomController *controller in rooms) {
		if (!controller.connection.connected)
			continue;
		[controller sendMessage:arguments asAction:YES];
	}

	return YES;
}

- (BOOL) handleJoinCommandWithArguments:(NSString *) arguments {
	if (![arguments stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length) {
		CQChatCreationViewController *creationViewController = [[CQChatCreationViewController alloc] init];
		creationViewController.roomTarget = YES;
		creationViewController.selectedConnection = self.connection;

		[self _forceRegsignKeyboard];

		[[CQColloquyApplication sharedApplication] presentModalViewController:creationViewController animated:YES];

		return YES;
	}

	[self.connection connectAppropriately];

	NSArray *rooms = [arguments componentsSeparatedByString:@","];
	if (rooms.count == 1 && ((NSString *)rooms[0]).length)
		[[CQChatController defaultController] showChatControllerWhenAvailableForRoomNamed:rooms[0] andConnection:self.connection];
	else if (rooms.count > 1)
		[[CQColloquyApplication sharedApplication] showColloquies:nil];

	// Return NO so the command is handled in ChatCore.
	return NO;
}

- (BOOL) handleJCommandWithArguments:(NSString *) arguments {
	return [self handleJoinCommandWithArguments:arguments];
}

- (BOOL) handleMsgCommandWithArguments:(NSString *) arguments {
	NSScanner *argumentsScanner = [NSScanner scannerWithString:arguments];
	[argumentsScanner setCharactersToBeSkipped:nil];

	NSString *targetName = nil;
	[argumentsScanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&targetName];

	BOOL hasMessageAfterCommand = !([argumentsScanner isAtEnd] || arguments.length <= argumentsScanner.scanLocation + 1);
	if (targetName.length > 1 && [[self.connection chatRoomNamePrefixes] characterIsMember:[targetName characterAtIndex:0]]) {
		MVChatRoom *room = [self.connection chatRoomWithUniqueIdentifier:targetName];
		CQChatRoomController *controller = [[CQChatOrderingController defaultController] chatViewControllerForRoom:room ifExists:NO];
		[[CQChatController defaultController] showChatController:controller animated:YES];
		if (hasMessageAfterCommand) [controller _sendText:[arguments substringFromIndex:argumentsScanner.scanLocation + 1]];
		return YES;
	} else {
		MVChatUser *user = [[self.connection chatUsersWithNickname:targetName] anyObject];
		CQDirectChatController *controller = [[CQChatOrderingController defaultController] chatViewControllerForUser:user ifExists:NO];
		[[CQChatController defaultController] showChatController:controller animated:YES];
		if (hasMessageAfterCommand) [controller _sendText:[arguments substringFromIndex:argumentsScanner.scanLocation + 1]];
		return YES;
	}

	// Return NO so the command is handled in ChatCore.
	return NO;
}

- (BOOL) handleNoticeCommandWithArguments:(NSString *) arguments {
	NSScanner *argumentsScanner = [NSScanner scannerWithString:arguments];
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

		NSString *message = [arguments substringFromIndex:argumentsScanner.scanLocation];
		NSData *messageData = [message dataUsingEncoding:self.connection.encoding];
		CQChatRoomController *controller = [[CQChatOrderingController defaultController] chatViewControllerForRoom:room ifExists:YES];
		[controller addMessage:@{ @"message": messageData, @"type": @"message", @"notice": @(YES), @"user": self.connection.localUser }];
	}

	// Return NO so the command is handled in ChatCore.
	return NO;
}

- (BOOL) handleOnoticeCommandWithArguments:(NSString *) arguments {
	if ([arguments hasPrefix:@"@"])
		return [self handleNoticeCommandWithArguments:arguments];
	return [self handleNoticeCommandWithArguments:[@"@" stringByAppendingString:arguments]];
}

- (BOOL) handleQueryCommandWithArguments:(NSString *) arguments {
	return [self handleMsgCommandWithArguments:arguments];
}

- (BOOL) handleClearCommandWithArguments:(NSString *) arguments {
	[self clearController];

	return YES;
}

- (BOOL) handleMusicCommandWithArguments:(NSString *) arguments {
	MPMusicPlayerController *musicController = [MPMusicPlayerController iPodMusicPlayer];
	MPMediaItem *nowPlayingItem = musicController.nowPlayingItem;

	if ([arguments isCaseInsensitiveEqualToString:@"next"] || [arguments isCaseInsensitiveEqualToString:@"skip"] || [arguments isCaseInsensitiveEqualToString:@"forward"]) 
		[musicController skipToNextItem];
	else if ([arguments isCaseInsensitiveEqualToString:@"previous"] || [arguments isCaseInsensitiveEqualToString:@"back"]) 
		[musicController skipToPreviousItem];
	else if ([arguments isCaseInsensitiveEqualToString:@"stop"] || [arguments isCaseInsensitiveEqualToString:@"pause"])
		[musicController stop];
	else if ([arguments isCaseInsensitiveEqualToString:@"play"] || [arguments isCaseInsensitiveEqualToString:@"resume"])
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

	[self sendMessage:message asAction:YES];

	return YES;
}

- (BOOL) handleIpodCommandWithArguments:(NSString *) arguments {
	return [self handleMusicCommandWithArguments:arguments];
}

- (BOOL) handleItunesCommandWithArguments:(NSString *) arguments {
	return [self handleMusicCommandWithArguments:arguments];
}

- (BOOL) handleNpCommandWithArguments:(NSString *) arguments {
	return [self handleMusicCommandWithArguments:arguments];
}

- (BOOL) handleSquitCommandWithArguments:(NSString *) arguments {
	if (self.connection.directConnection)
		return NO;

	[self.connection sendRawMessageImmediatelyWithComponents:@"SQUIT :", arguments, nil];

	return YES;
}

- (BOOL) handleListCommandWithArguments:(NSString *) arguments {
	CQChatCreationViewController *creationViewController = [[CQChatCreationViewController alloc] init];
	creationViewController.roomTarget = YES;
	creationViewController.selectedConnection = self.connection;

	[creationViewController showRoomListFilteredWithSearchString:arguments];

	[self _forceRegsignKeyboard];

	[[CQColloquyApplication sharedApplication] presentModalViewController:creationViewController animated:YES];

	return YES;
}

#pragma mark -

- (id) _findLocaleForQueryWithArguments:(NSString *) arguments {
	NSScanner *argumentsScanner = [NSScanner scannerWithString:arguments];
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
		query = [arguments substringWithRange:NSMakeRange(argumentsScanner.scanLocation + 1, (arguments.length - argumentsScanner.scanLocation - 1))];
	else query = arguments;

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

- (BOOL) handleGoogleCommandWithArguments:(NSString *) arguments {
	NSMutableArray *results = [self _findLocaleForQueryWithArguments:arguments];
	NSString *languageCode = results[0];
	NSString *query = results[1];

	[self _handleSearchForURL:@"http://www.google.com/m/search?q=%@&hl=%@" withQuery:query withLocale:languageCode];

	return YES;
}

- (BOOL) handleWikipediaCommandWithArguments:(NSString *) arguments {
	NSArray *results = [self _findLocaleForQueryWithArguments:arguments];
	NSString *languageCode = results[0];
	NSString *query = results[1];

	[self _handleSearchForURL:@"http://www.wikipedia.org/search-redirect.php?search=%@&language=%@" withQuery:query withLocale:languageCode];

	return YES;
}

- (BOOL) handleAmazonCommandWithArguments:(NSString *) arguments {
	NSArray *results = [self _findLocaleForQueryWithArguments:arguments];
	NSString *languageCode = results[0];
	NSString *query = results[1];

	if ([languageCode isCaseInsensitiveEqualToString:@"en_gb"])
		[self _handleSearchForURL:@"http://www.amazon.co.uk/s/field-keywords=%@" withQuery:query withLocale:languageCode];
	else if ([languageCode isCaseInsensitiveEqualToString:@"de"])
		[self _handleSearchForURL:@"http://www.amazon.de/gp/aw/s.html?k=%@" withQuery:query withLocale:languageCode];
	else if ([languageCode isCaseInsensitiveEqualToString:@"cn"])
		[self _handleSearchForURL:@"http://www.amazon.cn/mn/searchApp?&keywords=%@" withQuery:query withLocale:languageCode];
	else if ([languageCode isCaseInsensitiveEqualToString:@"ja_jp"])
		[self _handleSearchForURL:@"http://www.amazon.co.jp/s/field-keywords=%@" withQuery:query withLocale:languageCode];
	else if ([languageCode isCaseInsensitiveEqualToString:@"fr"])
		[self _handleSearchForURL:@"http://www.amazon.fr/s/field-keywords=%@" withQuery:query withLocale:languageCode];
	else if ([languageCode isCaseInsensitiveEqualToString:@"ca"])
		[self _handleSearchForURL:@"http://www.amazon.ca/s/field-keywords=%@" withQuery:query withLocale:languageCode];
	else [self _handleSearchForURL:@"http://www.amazon.com/gp/aw/s.html?k=%@" withQuery:query withLocale:languageCode];

	return YES;
}

- (BOOL) handleHelpCommandWithArguments:(NSString *) arguments {
	[self _forceRegsignKeyboard];

	[[CQColloquyApplication sharedApplication] showHelp:nil];

	return YES;
}

- (BOOL) handleFaqCommandWithArguments:(NSString *) arguments {
	[self handleHelpCommandWithArguments:arguments];

	return YES;
}

- (BOOL) handleWelcomeCommandWithArguments:(NSString *) arguments {
	[self _forceRegsignKeyboard];

	[[CQColloquyApplication sharedApplication] showWelcome:nil];

	return YES;
}

- (BOOL) handleSearchCommandWithArguments:(NSString *) arguments {
	NSString *urlString = @"http://searchirc.com/search.php?F=partial&I=%@&T=both&N=all&M=min&C=5&PER=20";

	[self _handleSearchForURL:urlString withQuery:arguments];

	return YES;
}

- (BOOL) handleTweetCommandWithArguments:(NSString *) arguments {
	SLComposeViewController *composeViewController = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
	composeViewController.completionHandler = ^(SLComposeViewControllerResult result) { /* do nothing */ };
	[self.navigationController presentViewController:composeViewController animated:YES completion:NULL];

	return YES;
}

- (BOOL) handleSysinfoCommandWithArguments:(NSString *) arguments {
	NSString *version = [[CQSettingsController settingsController] stringForKey:@"CQCurrentVersion"];
	NSString *orientation = UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation) ? NSLocalizedString(@"landscape", @"landscape orientation") : NSLocalizedString(@"portrait", @"portrait orientation");
	NSString *model = [UIDevice currentDevice].localizedModel;
	NSString *systemVersion = [NSProcessInfo processInfo].operatingSystemVersionString;
	NSString *systemUptime = humanReadableTimeInterval([NSProcessInfo processInfo].systemUptime, YES);
	NSUInteger processorsInTotal = [NSProcessInfo processInfo].processorCount;

	long long physicalMemory = [NSProcessInfo processInfo].physicalMemory;
	NSUInteger loopCount = 0;
	for ( ; physicalMemory > 1024; loopCount++)
		physicalMemory /= 1024;

	NSString *memoryUnit = nil;
	switch (loopCount) {
	case 0:
		memoryUnit = @"B";
		break;
	case 1:
		memoryUnit = @"KiB";
		break;
	case 2:
		memoryUnit = @"MiB";
		break;
	case 3:
		memoryUnit = @"GiB";
		break;
	case 4:
		memoryUnit = @"TiB";
		break;
	default:
		memoryUnit = @"Units";
		break;
	}
	NSString *systemMemory = [NSString stringWithFormat:@"%zd %@", physicalMemory, memoryUnit];

	BOOL batteryMonitoringEnabled = [UIDevice currentDevice].batteryMonitoringEnabled;
	[UIDevice currentDevice].batteryMonitoringEnabled = YES;
	NSString *message = nil;
	if ([UIDevice currentDevice].batteryState >= UIDeviceBatteryStateUnplugged)
		message = [NSString stringWithFormat:NSLocalizedString(@"is running Mobile Colloquy %@ in %@ mode on an %@ running iOS %@ with %d processors, %@ RAM, %.0f%% battery life remaining and a system uptime of %@.", @"System info message with battery level"), version, orientation, model, systemVersion, processorsInTotal, systemMemory, [UIDevice currentDevice].batteryLevel * 100., systemUptime];
	else message = [NSString stringWithFormat:NSLocalizedString(@"is running Mobile Colloquy %@ in %@ mode on an %@ running iOS %@ with %d processors, %@ RAM and a system uptime of %@.", @"System info message"), version, orientation, model, systemVersion, processorsInTotal, systemMemory, systemUptime];
	[UIDevice currentDevice].batteryMonitoringEnabled = batteryMonitoringEnabled;

	[self sendMessage:message asAction:YES];

	return YES;
}

- (void) handleZncCommandWithArguments:(NSString *) arguments {
	[self handleMsgCommandWithArguments:[NSString stringWithFormat:@"*status %@", arguments]];
}

#pragma mark -

- (BOOL) handleWhoisCommandWithArguments:(NSString *) arguments {
	if (arguments.length) {
		NSString *nick = [arguments componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]][0];
		[self _showUserInfoControllerForUserNamed:nick];
	} else if (self.user) {
		[self _showUserInfoControllerForUser:self.user];
	} else {
		return NO;
	}

	return YES;
}

- (BOOL) handleWiCommandWithArguments:(NSString *) arguments {
	return [self handleWhoisCommandWithArguments:arguments];
}

- (BOOL) handleWiiCommandWithArguments:(NSString *) arguments {
	return [self handleWhoisCommandWithArguments:arguments];
}

#if ENABLE(FILE_TRANSFERS)
- (BOOL) handleDccCommandWithArguments:(NSString *) arguments {
	if (!arguments.length)
		return NO;

	NSString *nick = [[arguments componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] objectAtIndex:0];
	MVChatUser *user = [[self.connection chatUsersWithNickname:nick] anyObject];
	[[CQChatController defaultController] showFilePickerWithUser:user];

	return YES;
}
#endif

#pragma mark -

- (BOOL) handleIgnoreCommandWithArguments:(NSString *) arguments {
	KAIgnoreRule *ignoreRule = nil;

	if (arguments.isValidIRCMask)
		ignoreRule = [KAIgnoreRule ruleForUser:nil mask:arguments message:nil inRooms:nil isPermanent:YES friendlyName:nil];
	else ignoreRule = [KAIgnoreRule ruleForUser:arguments mask:nil message:nil inRooms:nil isPermanent:YES friendlyName:nil];

	[self.connection.ignoreController addIgnoreRule:ignoreRule];

	return YES;
}

- (BOOL) handleUnignoreCommandWithArguments:(NSString *) arguments {
	[self.connection.ignoreController removeIgnoreRuleFromString:arguments];

	return YES;
}

#pragma mark -

- (BOOL) handleTokenCommandWithArguments:(NSString *) arguments {
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

- (void) handleResetbadgeCommandWithArguments:(NSString *) arguments {
	[CQColloquyApplication sharedApplication].applicationIconBadgeNumber = 0;
}

#pragma mark -

- (void) _handleKeyCommand:(UIKeyCommand *) command {
	id nextViewController = nil;

	BOOL optKeyPressed = (command.modifierFlags & UIKeyModifierAlternate) == UIKeyModifierAlternate;
	BOOL shiftKeyPressed = (command.modifierFlags & UIKeyModifierShift) == UIKeyModifierShift;
	BOOL commandKeyPressed = (command.modifierFlags & UIKeyModifierCommand) == UIKeyModifierCommand;

	if ([command.input isEqualToString:@"\t"]) {
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

	[[UIApplication sharedApplication] openURL:url];

	return YES;
}

- (void) transcriptView:(id) transcriptView handleNicknameTap:(NSString *) nickname atLocation:(CGPoint) location {
	[self _showUserInfoControllerForUserNamed:nickname];
}

- (void) transcriptView:(id) transcriptView handleLongPressURL:(NSURL *) url atLocation:(CGPoint) location {
	UIActionSheet *actionSheet = [[UIActionSheet alloc] init];
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

		[_recentMessages removeAllObjects];
	}
}

#pragma mark -

- (void) resetDidSendRecently {
	_didSendRecently = NO;
}

- (void) checkTranscriptViewForBecomeFirstResponder {
	if (_didSendRecently || ![transcriptView canBecomeFirstResponder])
		return;

	[self _forceRegsignKeyboard];
}

- (void) setScrollbackLength:(NSUInteger) scrollbackLength {
	[transcriptView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"setScrollbackLimit(%tu)", scrollbackLength] completionHandler:NULL];
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
	[UIView animateWithDuration:(_active ? animationDuration : .0) delay:.0 options:animationCurve animations:^{
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

	[UIView animateWithDuration:((_active && self.view.window) ? animationDuration : .0) delay:.0 options:(animationCurve << 16) animations:^{
		containerView.frame = self.view.bounds;
	} completion:NULL];
}

#pragma mark -

- (void) scrollbackLengthDidChange:(NSNotification *) notification {
	[self setScrollbackLength:scrollbackLength];
}

#pragma mark -

- (void) sendMessage:(NSString *) message asAction:(BOOL) action {
	[_target sendMessage:message withEncoding:self.encoding asAction:action];

	[_sentMessages addObject:@{ @"message": message, @"action": @(action) }];
	while (_sentMessages.count > 10)
		[_sentMessages removeObjectAtIndex:0];

	NSData *messageData = [message dataUsingEncoding:self.encoding allowLossyConversion:YES];
	[self addMessage:messageData fromUser:self.connection.localUser asAction:action withIdentifier:[NSString locallyUniqueString]];
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

		if ([self isMemberOfClass:[CQDirectChatController class]])
			voiceOverAnnouncement = plainMessage;
		else voiceOverAnnouncement = [NSString stringWithFormat:NSLocalizedString(@"In %@, %@", @"VoiceOver event announcement"), self.title, plainMessage];

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

- (void) willPresentAlertView:(UIAlertView *) alertView {
	_showingAlert = YES;
}

- (void) alertView:(UIAlertView *) alertView didDismissWithButtonIndex:(NSInteger) buttonIndex {
	_showingAlert = NO;
}

- (void) alertView:(UIAlertView *) alertView clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (buttonIndex == alertView.cancelButtonIndex)
		return;

	if (alertView.tag == ReconnectAlertTag) 
		[self.connection connectAppropriately];
	else if (alertView.tag == BookmarkLogInAlertView) {
		[[CQBookmarkingController activeService] setUsername:[alertView textFieldAtIndex:0].text password:[alertView textFieldAtIndex:1].text];
		[[CQBookmarkingController activeService] bookmarkLink:[alertView associatedObjectForKey:@"link"]];
	}
}

#pragma mark -

- (void) actionSheet:(UIActionSheet *) actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (buttonIndex == actionSheet.cancelButtonIndex)
		return;

	if (actionSheet.tag == InfoActionSheet) {
		if (buttonIndex == 0)
			[self showUserInformation];
	} else if (actionSheet.tag == ActionsActionSheet) {
		if (buttonIndex == 0)
			[self showRecentlySentMessages];
	} else if (actionSheet.tag == URLActionSheet) {
		Class <CQBookmarking> bookmarkingService = [CQBookmarkingController activeService];
		NSURL *URL = [actionSheet associatedObjectForKey:@"URL"];

		if (buttonIndex == 0)
			[[UIApplication sharedApplication] openURL:URL];
		else if (bookmarkingService && buttonIndex == 1)
			[bookmarkingService bookmarkLink:URL.absoluteString];
		else if ((!bookmarkingService && buttonIndex == 1) || (bookmarkingService && buttonIndex == 2))
			[[UIPasteboard generalPasteboard] setURL:URL];
	}
}

#pragma mark -

- (void) _showUserInfoControllerForUserNamed:(NSString *) nickname {
	[self _showUserInfoControllerForUser:[[self.connection chatUsersWithNickname:nickname] anyObject]];
}

- (void) _showUserInfoControllerForUser:(MVChatUser *) user {
	CQUserInfoController *userInfoController = [[CQUserInfoController alloc] init];
	userInfoController.user = user;

	[self _forceRegsignKeyboard];

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

- (void) _forceRegsignKeyboard {
	_allowEditingToEnd = YES;
	[chatInputBar resignFirstResponder];
	_allowEditingToEnd = NO;
}

- (void) _showCantSendMessagesWarningForCommand:(BOOL) command {
	UIAlertView *alert = [[CQAlertView alloc] init];
	alert.delegate = self;
	alert.tag = CantSendMessageAlertView;

	alert.cancelButtonIndex = [alert addButtonWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title")];

	if (command) alert.title = NSLocalizedString(@"Can't Send Command", @"Can't send command alert title");
	else alert.title = NSLocalizedString(@"Can't Send Message", @"Can't send message alert title");

	if (self.connection.status == MVChatConnectionConnectingStatus) {
		alert.message = NSLocalizedString(@"You are currently connecting,\ntry sending again soon.", @"Can't send message to user because server is connecting alert message");
	} else if (!self.connection.connected) {
		alert.tag = ReconnectAlertTag;
		alert.message = NSLocalizedString(@"You are currently disconnected,\nreconnect and try again.", @"Can't send message to user because server is disconnected alert message");
		[alert addButtonWithTitle:NSLocalizedString(@"Connect", @"Connect button title")];
	} else if (self.user.status != MVChatUserAvailableStatus && self.user.status != MVChatUserAwayStatus) {
		alert.message = NSLocalizedString(@"The user is not connected.", @"Can't send message to user because they are disconnected alert message");
	} else {
		return;
	}

	[alert show];
}

- (void) _userDefaultsChanged {
	if (![NSThread isMainThread])
		return;

	if (self.user)
		_encoding = [[CQSettingsController settingsController] integerForKey:@"CQDirectChatEncoding"];

	NSString *chatTranscriptFontSizeString = [[CQSettingsController settingsController] stringForKey:@"CQChatTranscriptFontSize"];
	NSUInteger chatTranscriptFontSize = [UIFont preferredFontForTextStyle:UIFontTextStyleBody].pointSize;

	const float CQDefaultDynamicTypeFontSize = 17.;

	if (chatTranscriptFontSize == CQDefaultDynamicTypeFontSize) {
		if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
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
	transcriptView.allowSingleSwipeGesture = ([UIDevice currentDevice].isPhoneModel || ![[CQColloquyApplication sharedApplication] splitViewController:nil shouldHideViewController:nil inOrientation:[UIApplication sharedApplication].statusBarOrientation]);

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

	[transcriptView noteNicknameChangedFrom:(notification.userInfo)[@"oldNickname"] to:user.nickname];

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

- (void) _didEnterBackground {
	[self markScrollback];
}

- (void) _willEnterForeground {
	[self _addPendingComponentsAnimated:NO];
}

- (void) _willBecomeActive {
	[self _addPendingComponentsAnimated:NO];

	if (_unreadHighlightedMessages)
		[CQChatController defaultController].totalImportantUnreadCount -= _unreadHighlightedMessages;

	if (_unreadMessages && self.user)
		[CQChatController defaultController].totalImportantUnreadCount -= _unreadMessages;

	_unreadMessages = 0;
	_unreadHighlightedMessages = 0;

	[[NSNotificationCenter defaultCenter] postNotificationName:CQChatViewControllerUnreadMessagesUpdatedNotification object:self];
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
}

- (void) _didRecieveDeviceToken:(NSNotification *) notification {
	if (_showDeviceTokenWhenRegistered)
		[self handleTokenCommandWithArguments:nil];
}

- (void) _awayStatusChanged:(NSNotification *) notification {
	if (self.connection.awayStatusMessage.length) {
		NSString *eventMessageFormat = [NSLocalizedString(@"You have set yourself as away with the message \"%@\".", "Marked as away event message") stringByEncodingXMLSpecialCharactersAsEntities];
		[self addEventMessageAsHTML:[NSString stringWithFormat:eventMessageFormat, self.connection.awayStatusMessage] withIdentifier:@"awaySet"];
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

	if (_active && [[UIDevice currentDevice] isPadModel])
		[[CQChatController defaultController].chatPresentationController updateToolbarAnimated:YES];

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

- (void) _showLocalNotificationForMessage:(NSDictionary *) message withSoundName:(NSString *) soundName {
	if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground)
		return;

	UILocalNotification *notification = [[UILocalNotification alloc] init];

	notification.alertBody = [self _localNotificationBodyForMessage:message];
	notification.userInfo = [self _localNotificationUserInfoForMessage:message];
	notification.soundName = [soundName stringByAppendingPathExtension:@"aiff"];

	[[UIApplication sharedApplication] presentLocalNotificationNow:notification];
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

		[[NSNotificationCenter defaultCenter] postNotificationName:CQChatViewControllerUnreadMessagesUpdatedNotification object:self];

		if (self.user || highlighted)
			++[CQChatController defaultController].totalImportantUnreadCount;
	}

	if (user.isLocalUser)
		self.mostRecentOutgoingMessageTimestamp = message[@"time"] ?: [NSDate date];
	else self.mostRecentIncomingMessageTimestamp = message[@"time"] ?: [NSDate date];

	[[NSNotificationCenter defaultCenter] postNotificationName:CQChatViewControllerHandledMessageNotification object:self];

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
		[[NSNotificationCenter defaultCenter] postNotificationName:CQChatViewControllerRecentMessagesUpdatedNotification object:self];

//	[operation.processedMessageInfo[CQInlineGIFImageKey] enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
//		CQIntroductoryGIFFrameOperation *GIFOperation = [[CQIntroductoryGIFFrameOperation alloc] initWithURL:object];
//		GIFOperation.userInfo = @{ @"id": key };
//		GIFOperation.target = self;
//		GIFOperation.action = @selector(_GIFProcessed:);
//
//		[[CQDirectChatController chatMessageProcessingQueue] addOperation:GIFOperation];
//	}];
}

- (void) _GIFProcessed:(CQIntroductoryGIFFrameOperation *) operation {
	NSString *base64Encoding = operation.introductoryFrameImageData.base64Encoding;
	NSString *imageString = nil;
	if (base64Encoding.length)
		imageString = [NSString stringWithFormat:@"data:image;base64, %@", base64Encoding];
	else imageString = operation.url.absoluteString;
	[transcriptView insertImage:imageString forElementWithIdentifier:operation.userInfo[@"id"]];

}
@end
