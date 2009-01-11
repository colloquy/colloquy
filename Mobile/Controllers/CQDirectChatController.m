#import "CQDirectChatController.h"

#import "CQChatController.h"
#import "CQChatInputBar.h"
#import "CQChatInputField.h"
#import "CQChatRoomController.h"
#import "CQChatTableCell.h"
#import "CQColloquyApplication.h"
#import "CQStyleView.h"
#import "CQWhoisNavController.h"
#import "NSDictionaryAdditions.h"
#import "NSScannerAdditions.h"
#import "NSStringAdditions.h"

#import <AGRegex/AGRegex.h>

#import <AudioToolbox/AudioToolbox.h>

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatUser.h>
#import <ChatCore/MVChatUserWatchRule.h>

#import <objc/message.h>

@interface CQDirectChatController (CQDirectChatControllerPrivate)
- (void) _showCantSendMessagesWarningForCommand:(BOOL) command;
- (NSDictionary *) _processMessage:(NSDictionary *) message highlightedMessage:(BOOL *) highlighted;
@end

#pragma mark -

@implementation CQDirectChatController
- (id) initWithTarget:(id) target {
	if (!(self = [super initWithNibName:@"ChatView" bundle:nil]))
		return nil;

	_target = [target retain];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_awayStatusChanged:) name:MVChatConnectionSelfAwayStatusChangedNotification object:self.connection];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didDisconnect:) name:MVChatConnectionDidDisconnectNotification object:self.connection];

	if (self.user) {
		UIBarButtonItem *infoItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"info.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(showUserInformation)];
		self.navigationItem.rightBarButtonItem = infoItem;
		[infoItem release];

		_encoding = [[NSUserDefaults standardUserDefaults] integerForKey:@"CQDirectChatEncoding"];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_userNicknameDidChange:) name:MVChatUserNicknameChangedNotification object:self.user];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didConnect:) name:MVChatConnectionDidConnectNotification object:self.connection];

		_watchRule = [[MVChatUserWatchRule alloc] init];
		_watchRule.nickname = self.user.nickname;

		[self.connection addChatUserWatchRule:_watchRule];

		_initialView = YES;
	}

	return self;
}

- (id) initWithPersistentState:(NSDictionary *) state usingConnection:(MVChatConnection *) connection {
	if (!_target) {
		NSString *nickname = [state objectForKey:@"user"];
		if (!nickname) {
			[self release];
			return nil;
		}

		MVChatUser *user = [connection chatUserWithUniqueIdentifier:nickname];
		if (!user) {
			[self release];
			return nil;
		}

		if (!(self = [self initWithTarget:user]))
			return nil;

		_initialView = NO;
	}

	_active = [[state objectForKey:@"active"] boolValue];

	_pendingPreviousSessionComponents = [[NSMutableArray alloc] init];

	for (NSDictionary *message in [state objectForKey:@"messages"]) {
		NSMutableDictionary *messageCopy = [message mutableCopy];

		MVChatUser *user = nil;
		if ([[messageCopy objectForKey:@"localUser"] boolValue]) {
			user = connection.localUser;
			[messageCopy removeObjectForKey:@"localUser"];
		} else user = [connection chatUserWithUniqueIdentifier:[messageCopy objectForKey:@"user"]];

		if (user) {
			[messageCopy setObject:user forKey:@"user"];

			[_pendingPreviousSessionComponents addObject:messageCopy];
		}

		[messageCopy release];
	}

	_recentMessages = [_pendingPreviousSessionComponents mutableCopy];

	while (_recentMessages.count > 10)
		[_recentMessages removeObjectAtIndex:0];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	if (_watchRule)
		[self.connection removeChatUserWatchRule:_watchRule];

	[chatInputBar release];
	[transcriptView release];
	[_watchRule release];
	[_recentMessages release];
	[_pendingPreviousSessionComponents release];
	[_pendingComponents release];
	[_target release];

	[super dealloc];
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
	NSMutableDictionary *state = [[NSMutableDictionary alloc] init];

	[state setObject:NSStringFromClass([self class]) forKey:@"class"];

	if ([CQChatController defaultController].topViewController == self)
		[state setObject:[NSNumber numberWithBool:YES] forKey:@"active"];

	if (self.user)
		[state setObject:self.user.nickname forKey:@"user"];

	NSMutableArray *messages = [[NSMutableArray alloc] init];

	for (NSDictionary *message in _recentMessages) {
		id sameKeys[] = {@"message", @"action", @"notice", @"highlighted", @"identifier", @"type", nil};
		NSMutableDictionary *newMessage = [[NSMutableDictionary alloc] initWithKeys:sameKeys fromDictionary:message];

		MVChatUser *user = [message objectForKey:@"user"];
		if (user && !user.localUser) [newMessage setObject:user.nickname forKey:@"user"];
		else if (user.localUser) [newMessage setObject:[NSNumber numberWithBool:YES] forKey:@"localUser"];

		[messages addObject:newMessage];

		[newMessage release];
	}

	if (messages.count)
		[state setObject:messages forKey:@"messages"];

	[messages release];

	return [state autorelease];
}

#pragma mark -

- (NSUInteger) unreadCount {
	return _unreadMessages;
}

- (NSUInteger) importantUnreadCount {
	return _unreadHighlightedMessages;
}

#pragma mark -

- (void) showUserInformation {
	if (!self.user)
		return;

	CQWhoisNavController *whoisController = [[CQWhoisNavController alloc] init];
	whoisController.user = self.user;

	_allowEditingToEnd = YES;
	[chatInputBar resignFirstResponder];
	_allowEditingToEnd = NO;

	[self presentModalViewController:whoisController animated:YES];

	[whoisController release];
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	transcriptView.styleIdentifier = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQChatTranscriptStyle"];
	self.view.backgroundColor = transcriptView.backgroundColor;

	NSString *completionBehavior = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQChatAutocompleteBehavior"];
	chatInputBar.autocomplete = ![completionBehavior isEqualToString:@"Disabled"];
	chatInputBar.spaceCyclesCompletions = [completionBehavior isEqualToString:@"Keyboard"];

	chatInputBar.autocorrect = ![[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableChatAutocorrection"];

	if (_pendingPreviousSessionComponents) {
		[transcriptView addPreviousSessionComponents:_pendingPreviousSessionComponents];

		[_pendingPreviousSessionComponents release];
		_pendingPreviousSessionComponents = nil;
	}

	if (_pendingComponents) {
		[transcriptView addComponents:_pendingComponents animated:NO];

		[_pendingComponents release];
		_pendingComponents = nil;
	}
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	_active = YES;

	if (_pendingComponents) {
		[transcriptView addComponents:_pendingComponents animated:NO];

		[_pendingComponents release];
		_pendingComponents = nil;
	}

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void) viewDidAppear:(BOOL) animated {
	[super viewDidAppear:animated];

	[transcriptView flashScrollIndicators];

	if (_unreadHighlightedMessages)
		[CQChatController defaultController].totalImportantUnreadCount -= _unreadHighlightedMessages;

	if (_unreadMessages && self.user)
		[CQChatController defaultController].totalImportantUnreadCount -= _unreadMessages;

	_unreadMessages = 0;
	_unreadHighlightedMessages = 0;

	if(_initialView) {
		_initialView = NO;
		[chatInputBar performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:0.5];
	}
}

- (void) viewWillDisappear:(BOOL) animated {
	[chatInputBar hideCompletions];

	_active = NO;
	_allowEditingToEnd = YES;

	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];

	[super viewWillDisappear:animated];
}

- (void) viewDidDisappear:(BOOL) animated {
	[super viewDidDisappear:animated];

	[chatInputBar resignFirstResponder];

	_allowEditingToEnd = NO;
}

- (void) didRotateFromInterfaceOrientation:(UIInterfaceOrientation) fromInterfaceOrientation {
	[transcriptView scrollToBottomAnimated:NO];
}

- (void) didReceiveMemoryWarning {
	// Do nothing for now, since calling super will release the view and
	// the transcript view with all the chat history.
}

#pragma mark -

- (void) chatInputBarDidBeginEditing:(CQChatInputBar *) chatInputBar {
	[transcriptView scrollToBottomAnimated:NO];
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
		if (!services) services = [[NSArray alloc] initWithObjects:@"NickServ", @"ChanServ", @"MemoServ", nil];

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
		if (!commands) commands = [[NSArray alloc] initWithObjects:@"/me", @"/msg", @"/nick", @"/away", @"/say", @"/raw", @"/quote", @"/join", @"/quit", @"/disconnect", @"/query", @"/umode", @"/globops", @"/google", @"/wikipedia", @"/amazon", @"/browser", @"/url", @"/part", @"/whois", @"/clear", @"/notice", nil];

		for (NSString *command in commands) {
			if ([command hasCaseInsensitivePrefix:word] && ![command isCaseInsensitiveEqualToString:word])
				[completions addObject:command];
			if (completions.count >= 10)
				break;
		}
	}

	if (completions.count < 10 && ([word containsTypicalEmoticonCharacters] || [word hasCaseInsensitivePrefix:@"x"] || [word hasCaseInsensitivePrefix:@"o"])) {
		for (NSString *emoticon in [NSString knownEmoticons]) {
			if ([emoticon hasCaseInsensitivePrefix:word] && ![emoticon isCaseInsensitiveEqualToString:word])
				[completions addObject:[emoticon stringBySubstitutingEmoticonsForEmoji]];
			if (completions.count >= 10)
				break;
		}
	}

	return [completions autorelease];
}

- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar sendText:(NSString *) text {
	_didSendRecently = YES;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(resetDidSendRecently) object:nil];
	[self performSelector:@selector(resetDidSendRecently) withObject:nil afterDelay:0.5];

	if ([text hasPrefix:@"/"] && ![text hasPrefix:@"//"]) {
		static NSArray *commandsNotRequiringConnection;
		if (!commandsNotRequiringConnection)
			commandsNotRequiringConnection = [[NSArray alloc] initWithObjects:@"google", @"wikipedia", @"amazon", @"browser", @"url", @"connect", @"reconnect", @"clear", nil];

		// Send as a command.
		NSScanner *scanner = [NSScanner scannerWithString:text];
		[scanner setCharactersToBeSkipped:nil];

		NSString *command = nil;
		NSString *arguments = nil;

		[scanner scanString:@"/" intoString:nil];
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
		if ([text hasPrefix:@"/"])
			text = [text substringFromIndex:1];

		[_target sendMessage:text withEncoding:self.encoding asAction:NO];

		NSData *messageData = [text dataUsingEncoding:self.encoding allowLossyConversion:YES];
		[self addMessage:messageData fromUser:self.connection.localUser asAction:NO withIdentifier:[NSString locallyUniqueString]];
	}

	return YES;
}

#pragma mark -

- (BOOL) _openURL:(NSURL *) url preferBuiltInBrowser:(BOOL) preferBrowser {
	BOOL openWithBrowser = preferBrowser || ![[NSUserDefaults standardUserDefaults] boolForKey:@"CQDisableBuiltInBrowser"];

	if (openWithBrowser) {
		_allowEditingToEnd = YES;
		[chatInputBar resignFirstResponder];
		_allowEditingToEnd = NO;
	}

	return [[CQColloquyApplication sharedApplication] openURL:url usingBuiltInBrowser:openWithBrowser];
}

- (BOOL) _handleURLCommandWithArguments:(NSString *) arguments preferBuiltInBrowser:(BOOL) preferBrowser {
	NSScanner *scanner = [NSScanner scannerWithString:arguments];
	NSString *urlString = nil;

	[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&urlString];

	if (!preferBrowser && !urlString.length)
		return NO;

	NSURL *url = (urlString ? [NSURL URLWithString:urlString] : nil);
	if (urlString && !url.scheme.length) url = [NSURL URLWithString:[@"http://" stringByAppendingString:urlString]];

	[self _openURL:url preferBuiltInBrowser:preferBrowser];

	return YES;
}

- (BOOL) handleBrowserCommandWithArguments:(NSString *) arguments {
	return [self _handleURLCommandWithArguments:arguments preferBuiltInBrowser:YES];
}

- (BOOL) handleUrlCommandWithArguments:(NSString *) arguments {
	return [self _handleURLCommandWithArguments:arguments preferBuiltInBrowser:NO];
}

- (BOOL) handleJoinCommandWithArguments:(NSString *) arguments {
	NSArray *rooms = [arguments componentsSeparatedByString:@","];

	if (rooms.count == 1 && ((NSString *)[rooms objectAtIndex:0]).length)
		[[CQChatController defaultController] showChatControllerWhenAvailableForRoomNamed:[rooms objectAtIndex:0] andConnection:self.connection];
	else if (rooms.count > 1)
		[[CQChatController defaultController] popToRootViewControllerAnimated:YES];

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

	if ([argumentsScanner isAtEnd] || [arguments length] <= [argumentsScanner scanLocation] + 1) {
		if (targetName.length > 1 && [[self.connection chatRoomNamePrefixes] characterIsMember:[targetName characterAtIndex:0]]) {
			MVChatRoom *room = [self.connection chatRoomWithUniqueIdentifier:targetName];
			CQChatRoomController *controller = [[CQChatController defaultController] chatViewControllerForRoom:room ifExists:NO];
			[[CQChatController defaultController] showChatController:controller animated:YES];
			return YES;
		} else {
			MVChatUser *user = [[self.connection chatUsersWithNickname:targetName] anyObject];
			CQDirectChatController *controller = [[CQChatController defaultController] chatViewControllerForUser:user ifExists:NO];
			[[CQChatController defaultController] showChatController:controller animated:YES];
			return YES;
		}
	}

	// Return NO so the command is handled in ChatCore.
	return NO;
}

- (BOOL) handleQueryCommandWithArguments:(NSString *) arguments {
	return [self handleMsgCommandWithArguments:arguments];
}

- (BOOL) handleClearCommandWithArguments:(NSString *) arguments {
	[_pendingComponents release];
	_pendingComponents = nil;

	[_pendingPreviousSessionComponents release];
	_pendingPreviousSessionComponents = nil;

	[_recentMessages release];
	_recentMessages = nil;

	if (_unreadHighlightedMessages)
		[CQChatController defaultController].totalImportantUnreadCount -= _unreadHighlightedMessages;

	if (_unreadMessages && self.user)
		[CQChatController defaultController].totalImportantUnreadCount -= _unreadMessages;

	_unreadMessages = 0;
	_unreadHighlightedMessages = 0;

	[transcriptView reset];

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
//		if ([arguments 
		languageCode = [[NSLocale autoupdatingCurrentLocale] localeIdentifier];

		[results addObject:languageCode];
		[results addObject:arguments];

		return [results autorelease];
	}

	NSString *query = nil;
	if (arguments.length >= ([argumentsScanner scanLocation] + 1))
		query = [arguments substringWithRange:NSMakeRange([argumentsScanner scanLocation] + 1, ([arguments length] - [argumentsScanner scanLocation] - 1))];
	else query = arguments;

	[results addObject:languageCode];
	[results addObject:query];

	return [results autorelease];
}

- (void) _handleSearchForURL:(NSString *) urlFormatString withQuery:(NSString *) query withLocale:(NSString *) languageCode {
	NSString *urlString = [NSString stringWithFormat:urlFormatString, [query stringByEncodingIllegalURLCharacters], languageCode];
	NSURL *url = [NSURL URLWithString:urlString];
	[self _openURL:url preferBuiltInBrowser:NO];
}

- (BOOL) handleGoogleCommandWithArguments:(NSString *) arguments {
	NSMutableArray *results = [self _findLocaleForQueryWithArguments:arguments];
	NSString *languageCode = [results objectAtIndex:0];
	NSString *query = [results objectAtIndex:1];

	[self _handleSearchForURL:@"http://www.google.com/m/search?q=%@&hl=%@" withQuery:query withLocale:languageCode];

	return YES;
}

- (BOOL) handleWikipediaCommandWithArguments:(NSString *) arguments {
	NSArray *results = [self _findLocaleForQueryWithArguments:arguments];
	NSString *languageCode = [results objectAtIndex:0];
	NSString *query = [results objectAtIndex:1];
	
	[self _handleSearchForURL:@"http://www.wikipedia.org/search-redirect.php?search=%@&language=%@" withQuery:query withLocale:languageCode];

	return YES;
}

- (BOOL) handleAmazonCommandWithArguments:(NSString *) arguments {
	NSArray *results = [self _findLocaleForQueryWithArguments:arguments];
	NSString *languageCode = [results objectAtIndex:0];
	NSString *query = [results objectAtIndex:1];

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

#pragma mark -

- (BOOL) handleWhoisCommandWithArguments:(NSString *) arguments {
	CQWhoisNavController *whoisController = [[CQWhoisNavController alloc] init];

	if (arguments.length) {
		NSString *nick = [[arguments componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] objectAtIndex:0];
		whoisController.user = [[self.connection chatUsersWithNickname:nick] anyObject];
	} else if (self.user) {
		whoisController.user = self.user;
	} else {
		[whoisController release];
		return NO;
	}

	_allowEditingToEnd = YES;
	[chatInputBar resignFirstResponder];
	_allowEditingToEnd = NO;

	[self presentModalViewController:whoisController animated:YES];

	[whoisController release];

	return YES;
}

- (BOOL) handleWiCommandWithArguments:(NSString *) arguments {
	return [self handleWhoisCommandWithArguments:arguments];
}

- (BOOL) handleWiiCommandWithArguments:(NSString *) arguments {
	return [self handleWhoisCommandWithArguments:arguments];
}

#pragma mark -

- (BOOL) transcriptView:(CQChatTranscriptView *) transcriptView handleOpenURL:(NSURL *) url {
	if (![url.scheme isCaseInsensitiveEqualToString:@"irc"] && ![url.scheme isCaseInsensitiveEqualToString:@"ircs"])
		return [self _openURL:url preferBuiltInBrowser:NO];

	if (!url.host.length) {
		NSString *target = @"";
		if (url.fragment.length) target = [@"#" stringByAppendingString:url.fragment];
		else if (url.path.length > 1) target = url.path;

		url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@/%@", url.scheme, self.connection.server, target]];
	}

	[[UIApplication sharedApplication] openURL:url];

	return YES;
}

#pragma mark -

- (void) resetDidSendRecently {
	_didSendRecently = NO;
}

- (void) checkTranscriptViewForBecomeFirstResponder {
	if (_didSendRecently || ![transcriptView canBecomeFirstResponder])
		return;

	_allowEditingToEnd = YES;
	[chatInputBar resignFirstResponder];
	_allowEditingToEnd = NO;
}

#pragma mark -

- (void) keyboardWillShow:(NSNotification *) notification {
	CGPoint endCenterPoint = CGPointZero;
	CGRect keyboardBounds = CGRectZero;

	[[[notification userInfo] objectForKey:UIKeyboardCenterEndUserInfoKey] getValue:&endCenterPoint];
	[[[notification userInfo] objectForKey:UIKeyboardBoundsUserInfoKey] getValue:&keyboardBounds];

	endCenterPoint = [self.parentViewController.view convertPoint:endCenterPoint toView:self.view];

	BOOL previouslyShowingKeyboard = (chatInputBar.center.y != (self.view.bounds.size.height - (chatInputBar.bounds.size.height / 2.)));
	if (!previouslyShowingKeyboard) {
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.25];

#if defined(TARGET_IPHONE_SIMULATOR) && TARGET_IPHONE_SIMULATOR
		[UIView setAnimationDelay:0.06];
#else
		[UIView setAnimationDelay:0.175];
#endif
	}

	BOOL landscape = UIInterfaceOrientationIsLandscape(self.interfaceOrientation);
	CGFloat windowOffset = (landscape ? [UIApplication sharedApplication].statusBarFrame.size.width : [UIApplication sharedApplication].statusBarFrame.size.height);

	CGRect bounds = chatInputBar.bounds;
	CGPoint center = chatInputBar.center;
	CGFloat keyboardTop = MAX(chatInputBar.bounds.size.height, endCenterPoint.y - (keyboardBounds.size.height / 2.));
	center.y = keyboardTop - (bounds.size.height / 2.) - windowOffset;
	chatInputBar.center = center;

	bounds = transcriptView.bounds;
	bounds.size.height = keyboardTop - chatInputBar.bounds.size.height - windowOffset;
	transcriptView.bounds = bounds;

	center = transcriptView.center;
	center.y = (bounds.size.height / 2.);
	transcriptView.center = center;

	if (!previouslyShowingKeyboard)
		[UIView commitAnimations];

	[transcriptView scrollToBottomAnimated:YES];
}

- (void) keyboardWillHide:(NSNotification *) notification {
	CGPoint beginCenterPoint = CGPointZero;
	CGPoint endCenterPoint = CGPointZero;

	[[[notification userInfo] objectForKey:UIKeyboardCenterBeginUserInfoKey] getValue:&beginCenterPoint];
	[[[notification userInfo] objectForKey:UIKeyboardCenterEndUserInfoKey] getValue:&endCenterPoint];

	if (beginCenterPoint.y == endCenterPoint.y)
		return;

	[UIView beginAnimations:nil context:NULL];

	[UIView setAnimationDuration:0.25];

	CGRect bounds = chatInputBar.bounds;
	CGPoint center = chatInputBar.center;
	CGFloat viewHeight = self.view.bounds.size.height;
	center.y = viewHeight - (bounds.size.height / 2.);
	chatInputBar.center = center;

	bounds = transcriptView.bounds;
	bounds.size.height = viewHeight - chatInputBar.bounds.size.height;
	transcriptView.bounds = bounds;

	center = transcriptView.center;
	center.y = (bounds.size.height / 2.);
	transcriptView.center = center;

	[UIView commitAnimations];
}

#pragma mark -

@synthesize recentMessages = _recentMessages;

- (void) addEventMessage:(NSString *) messageString withIdentifier:(NSString *) identifier {
	[self addEventMessageAsHTML:[messageString stringByEncodingXMLSpecialCharactersAsEntities] withIdentifier:identifier];
}

- (void) addEventMessageAsHTML:(NSString *) messageString withIdentifier:(NSString *) identifier {
	NSMutableDictionary *message = [[NSMutableDictionary alloc] init];

	[message setObject:@"event" forKey:@"type"];

	if (messageString) [message setObject:messageString forKey:@"message"];
	if (identifier) [message setObject:identifier forKey:@"identifier"];

	if (!transcriptView || !_active) {
		if (!_pendingComponents)
			_pendingComponents = [[NSMutableArray alloc] init];
		[_pendingComponents addObject:message];
	} else [transcriptView addComponent:message animated:YES];

	[message release];
}

- (void) addMessage:(NSData *) messageData fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier {
	NSMutableDictionary *message = [[NSMutableDictionary alloc] init];

	if (message) [message setObject:messageData forKey:@"message"];
	if (user) [message setObject:user forKey:@"user"];
	if (identifier) [message setObject:identifier forKey:@"identifier"];
	[message setObject:[NSNumber numberWithBool:action] forKey:@"action"];

	[self addMessage:message];

	[message release];
}

- (void) addMessage:(NSDictionary *) message {
	MVChatUser *user = [message objectForKey:@"user"];
	if (!user.localUser && !_active && self.available) {
		++_unreadMessages;
		if (self.user)
			++[CQChatController defaultController].totalImportantUnreadCount;
	}

	BOOL highlighted = NO;
	message = [self _processMessage:message highlightedMessage:&highlighted];

	if (highlighted && !_active && self.available) {
		++_unreadHighlightedMessages;
		if (!self.user)
			++[CQChatController defaultController].totalImportantUnreadCount;
	}

	if (highlighted && self.available && [[NSUserDefaults standardUserDefaults] boolForKey:@"CQVibrateOnHighlight"])
		AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);

	if (!_recentMessages)
		_recentMessages = [[NSMutableArray alloc] init];
	[_recentMessages addObject:message];

	while (_recentMessages.count > 10)
		[_recentMessages removeObjectAtIndex:0];

	if (!transcriptView || !_active) {
		if (!_pendingComponents)
			_pendingComponents = [[NSMutableArray alloc] init];
		[_pendingComponents addObject:message];
		return;
	}

	[transcriptView addComponent:message animated:YES];
}

#pragma mark -

- (void) willPresentAlertView:(UIAlertView *) alertView {
	_showingAlert = YES;
}

- (void) alertView:(UIAlertView *) alertView didDismissWithButtonIndex:(NSInteger) buttonIndex {
	_showingAlert = NO;
}

- (void) alertView:(UIAlertView *) alertView clickedButtonAtIndex:(NSInteger) buttonIndex {
	if (alertView.tag != 1 || buttonIndex != 0)
		return;

	[self.connection connect];
}

#pragma mark -

static void commonChatReplacment(NSMutableString *string, NSRangePointer textRange) {
	[string substituteEmoticonsForEmojiInRange:textRange withXMLSpecialCharactersEncodedAsEntities:YES];

	// Catch IRC rooms like "#room" but not HTML colors like "#ab12ef" nor HTML entities like "&#135;" or "&amp;".
	// Catch well-formed urls like "http://www.apple.com", "www.apple.com" or "irc://irc.javelin.cc".
	// Catch well-formed email addresses like "user@example.com" or "user@example.co.uk".
	static AGRegex *urlRegex;
	if (!urlRegex)
		urlRegex = [[AGRegex alloc] initWithPattern:@"(?P<room>\\B(?<!&amp;)#(?![\\da-fA-F]{6}\\b|\\d{1,3}\\b)[\\w-_.+&;#]{2,}\\b)|(?P<url>\\b(?:[a-zA-Z][a-zA-Z0-9+.-]{2,6}:(?://){0,1}|www\\.)[\\p{L}\\p{N}$\\-_+*'=\\|/\\\\)}\\]%@&#~,:;.!?][\\p{L}\\p{N}$\\-_+*'=\\|/\\\\(){}[\\]%@&#~,:;.!?]{3,}[\\p{L}\\p{N}$\\-_+*=\\|/\\\\({%@&#~])|(?P<email>[\\p{L}\\p{N}.+\\-_]+@(?:[\\p{L}\\-_]+\\.)+[\\w]{2,})" options:AGRegexCaseInsensitive];

	AGRegexMatch *match = [urlRegex findInString:string range:*textRange];
	while (match) {
		NSString *room = [match groupNamed:@"room"];
		NSString *url = [match groupNamed:@"url"];
		NSString *email = [match groupNamed:@"email"];

		NSString *linkHTMLString = nil;
		if (room.length) {
			linkHTMLString = [NSString stringWithFormat:@"<a href=\"irc:///%@\">%1$@</a>", room];
		} else if (url.length) {
			NSString *fullURL = ([url hasCaseInsensitivePrefix:@"www."] ? [@"http://" stringByAppendingString:url] : url);
			url = [url stringByReplacingOccurrencesOfString:@"/" withString:@"/\u200b"];
			url = [url stringByReplacingOccurrencesOfString:@"?" withString:@"?\u200b"];
			url = [url stringByReplacingOccurrencesOfString:@"=" withString:@"=\u200b"];
			url = [url stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&amp;\u200b"];
			linkHTMLString = [NSString stringWithFormat:@"<a href=\"%@\">%@</a>", fullURL, url];
		} else if (email.length) {
			linkHTMLString = [NSString stringWithFormat:@"<a href=\"mailto:%@\">%1$@</a>", email];
		}

		if (linkHTMLString) {
			[string replaceCharactersInRange:match.range withString:linkHTMLString];

			textRange->length += (linkHTMLString.length - match.range.length);
		}

		NSRange matchRange = NSMakeRange(match.range.location + linkHTMLString.length, (NSMaxRange(*textRange) - match.range.location - linkHTMLString.length));
		if (!matchRange.length)
			break;

		match = [urlRegex findInString:string range:matchRange];
	}
}

static void applyFunctionToTextInMutableHTMLString(NSMutableString *html, NSRangePointer range, void (*function)(NSMutableString *, NSRangePointer)) {
	if (!html || !function || !range)
		return;

	NSRange tagEndRange = NSMakeRange(range->location, 0);
	while (1) {
		NSRange tagStartRange = [html rangeOfString:@"<" options:NSLiteralSearch range:NSMakeRange(NSMaxRange(tagEndRange), (NSMaxRange(*range) - NSMaxRange(tagEndRange)))];
		if (tagStartRange.location == NSNotFound) {
			NSUInteger length = (NSMaxRange(*range) - NSMaxRange(tagEndRange));
			NSRange textRange = NSMakeRange(NSMaxRange(tagEndRange), length);
			if (length) {
				function(html, &textRange);
				range->length += (textRange.length - length);
			}

			break;
		}

		NSUInteger length = (tagStartRange.location - NSMaxRange(tagEndRange));
		NSRange textRange = NSMakeRange(NSMaxRange(tagEndRange), length);
		if (length) {
			function(html, &textRange);
			range->length += (textRange.length - length);
		}

		tagEndRange = [html rangeOfString:@">" options:NSLiteralSearch range:NSMakeRange(NSMaxRange(textRange), (NSMaxRange(*range) - NSMaxRange(textRange)))];
		if (tagEndRange.location == NSNotFound || NSMaxRange(tagEndRange) == NSMaxRange(*range))
			break;
	}
}

static NSString *applyFunctionToTextInHTMLString(NSString *html, void (*function)(NSMutableString *, NSRangePointer)) {
	if (!html || !function)
		return html;

	NSMutableString *result = [html mutableCopy];

	NSRange range = NSMakeRange(0, result.length);
	applyFunctionToTextInMutableHTMLString(result, &range, function);

	return [result autorelease];
}

#pragma mark -

- (NSMutableString *) _processMessageData:(NSData *) messageData {
	if (!messageData) return nil;

	NSMutableString *messageString = [[NSMutableString alloc] initWithChatData:messageData encoding:self.encoding];
	if (!messageString) messageString = [[NSMutableString alloc] initWithChatData:messageData encoding:NSASCIIStringEncoding];
	return [messageString autorelease];
}

- (void) _processMessageString:(NSMutableString *) messageString {
	if (!messageString.length) return;

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageFormatting"]) {
		[messageString stripXMLTags];

		NSRange range = NSMakeRange(0, messageString.length);
		commonChatReplacment(messageString, &range);
		return;
	}

	NSRange range = NSMakeRange(0, messageString.length);
	applyFunctionToTextInMutableHTMLString(messageString, &range, commonChatReplacment);
}

- (NSDictionary *) _processMessage:(NSDictionary *) message highlightedMessage:(BOOL *) highlighted {
	static NSMutableArray *mainHighlightWords;
	if (!mainHighlightWords) {
		mainHighlightWords = [[NSMutableArray alloc] init];

		NSString *highlightWordsString = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQHighlightWords"];
		if (highlightWordsString.length) {
			AGRegex *regex = [[AGRegex alloc] initWithPattern:@"(?<=\\s|^)([/\"'].*?[/\"'])(?=\\s|$)"];
			NSArray *matches = [regex findAllInString:highlightWordsString];

			for (AGRegexMatch *match in [matches objectEnumerator])
				[mainHighlightWords addObject:[match groupAtIndex:1]];

			highlightWordsString = [regex replaceWithString:@"" inString:highlightWordsString];

			[mainHighlightWords addObjectsFromArray:[highlightWordsString componentsSeparatedByString:@" "]];
			[mainHighlightWords removeObject:@""];

			[regex release];
		}
	}

	NSMutableArray *highlightWords = [mainHighlightWords mutableCopy];
	[highlightWords insertObject:self.connection.nickname atIndex:0];

	*highlighted = NO;

	NSMutableString *messageString = [self _processMessageData:[message objectForKey:@"message"]];

	MVChatUser *user = [message objectForKey:@"user"];
	if (!user.localUser && highlightWords.count) {
		NSCharacterSet *escapedCharacters = [NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"];
		NSCharacterSet *trimCharacters = [NSCharacterSet characterSetWithCharactersInString:@"\"'"];
		NSString *stylelessMessageString = [messageString stringByStrippingXMLTags];

		for (NSString *highlightWord in highlightWords) {
			if (!highlightWord.length)
				continue;

			AGRegex *regex = nil;
			if( [highlightWord hasPrefix:@"/"] && [highlightWord hasSuffix:@"/"] && highlightWord.length > 1 ) {
				regex = [[AGRegex alloc] initWithPattern:[highlightWord substringWithRange:NSMakeRange( 1, highlightWord.length - 2 )] options:AGRegexCaseInsensitive];
			} else {
				highlightWord = [highlightWord stringByTrimmingCharactersInSet:trimCharacters];
				highlightWord = [highlightWord stringByEscapingCharactersInSet:escapedCharacters];
				regex = [[AGRegex alloc] initWithPattern:[NSString stringWithFormat:@"(?<=^|\\s|[^\\w])%@(?=$|\\s|[^\\w])", highlightWord] options:AGRegexCaseInsensitive];
			}

			if ([regex findInString:stylelessMessageString])
				*highlighted = YES;

			[regex release];

			if (highlighted)
				break;
		}
	}

	NSString *transformedMessageString = nil;
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageFormatting"]) {
		[messageString stripXMLTags];

		NSRange range = NSMakeRange(0, messageString.length);
		commonChatReplacment(messageString, &range);

		transformedMessageString = messageString;
	} else transformedMessageString = applyFunctionToTextInHTMLString(messageString, commonChatReplacment);

	id sameKeys[] = {@"user", @"action", @"notice", @"identifier", nil};
	NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithKeys:sameKeys fromDictionary:message];

	[result setObject:@"message" forKey:@"type"];
	[result setObject:transformedMessageString forKey:@"message"];

	if (*highlighted)
		[result setObject:[NSNumber numberWithBool:YES] forKey:@"highlighted"];

	[highlightWords release];

	return [result autorelease];
}

- (void) _showCantSendMessagesWarningForCommand:(BOOL) command {
	UIAlertView *alert = [[UIAlertView alloc] init];
	alert.delegate = self;

	if (command) alert.title = NSLocalizedString(@"Can't Send Command", @"Can't send command alert title");
	else alert.title = NSLocalizedString(@"Can't Send Message", @"Can't send message alert title");

	if (self.connection.status == MVChatConnectionConnectingStatus) {
		alert.message = NSLocalizedString(@"You are currently connecting,\ntry sending again soon.", @"Can't send message to user because server is connecting alert message");
		alert.cancelButtonIndex = 0;
	} else if (!self.connection.connected) {
		alert.tag = 1;
		alert.message = NSLocalizedString(@"You are currently disconnected,\nreconnect and try again.", @"Can't send message to user because server is disconnected alert message");
		[alert addButtonWithTitle:NSLocalizedString(@"Connect", @"Connect alert button title")];
		alert.cancelButtonIndex = 1;
	} else if (self.user.status != MVChatUserAvailableStatus && self.user.status != MVChatUserAwayStatus) {
		alert.message = NSLocalizedString(@"The user is not connected.", @"Can't send message to user because they are disconnected alert message");
		alert.cancelButtonIndex = 0;
	} else {
		[alert release];
		return;
	}

	[alert addButtonWithTitle:NSLocalizedString(@"Close", @"Close alert button title")];

	[alert show];

	[alert release];
}

- (void) _userNicknameDidChange:(NSNotification *) notification {
	if (!_watchRule)
		return;

	[self.connection removeChatUserWatchRule:_watchRule];

	_watchRule.nickname = self.user.nickname;

	[self.connection addChatUserWatchRule:_watchRule];
}

- (void) _didConnect:(NSNotification *) notification {
	[self addEventMessage:NSLocalizedString(@"Connected to the server.", "Connected to server event message") withIdentifier:@"reconnected"];
}

- (void) _didDisconnect:(NSNotification *) notification {
	[self addEventMessage:NSLocalizedString(@"Disconnected from the server.", "Disconnect from the server event message") withIdentifier:@"disconnected"];
}

- (void) _awayStatusChanged:(NSNotification *) notification {
	if (self.connection.awayStatusMessage.length) {
		NSString *eventMessageFormat = [NSLocalizedString(@"You have set yourself as away with the message \"%@\".", "Marked as away event message") stringByEncodingXMLSpecialCharactersAsEntities];
		[self addEventMessageAsHTML:[NSString stringWithFormat:eventMessageFormat, self.connection.awayStatusMessage] withIdentifier:@"awaySet"];
	} else {
		[self addEventMessage:NSLocalizedString(@"You have returned from being away.", "Returned from being away event message") withIdentifier:@"awayRemoved"];
	}
}
@end
