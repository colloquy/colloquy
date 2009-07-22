#import "CQDirectChatController.h"

#import "CQChatController.h"
#import "CQChatInputBar.h"
#import "CQChatInputField.h"
#import "CQChatRoomController.h"
#import "CQChatTableCell.h"
#import "CQColloquyApplication.h"
#import "CQConnectionsController.h"
#import "CQProcessChatMessageOperation.h"
#import "CQStyleView.h"
#import "CQWhoisNavController.h"
#import "CQSoundController.h"
#import "NSDictionaryAdditions.h"
#import "NSScannerAdditions.h"
#import "NSStringAdditions.h"
#import "RegexKitLite.h"

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatUser.h>
#import <ChatCore/MVChatUserWatchRule.h>

#import <MediaPlayer/MPMusicPlayerController.h>
#import <MediaPlayer/MPMediaItem.h>

#import <objc/message.h>

NSString *CQChatViewControllerRecentMessagesUpdatedNotification = @"CQChatViewControllerRecentMessagesUpdated";

@interface CQDirectChatController (CQDirectChatControllerPrivate)
- (void) _addPendingComponent:(id) component;
- (void) _processMessageData:(NSData *) messageData target:(id) target action:(SEL) action userInfo:(id) userInfo;
- (void) _updateRightBarButtonItemAnimated:(BOOL) animated;
- (void) _showCantSendMessagesWarningForCommand:(BOOL) command;
- (void) _moveInputFieldForOrientation:(UIInterfaceOrientation) interfaceOrientation;
@end

#pragma mark -

static NSOperationQueue *chatMessageProcessingQueue;

#pragma mark -

@implementation CQDirectChatController
- (id) initWithTarget:(id) target {
	if (!(self = [super initWithNibName:@"ChatView" bundle:nil]))
		return nil;

	_target = [target retain];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_awayStatusChanged:) name:MVChatConnectionSelfAwayStatusChangedNotification object:self.connection];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didConnect:) name:MVChatConnectionDidConnectNotification object:self.connection];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didDisconnect:) name:MVChatConnectionDidDisconnectNotification object:self.connection];

	if (self.user) {
		[self _updateRightBarButtonItemAnimated:NO];

		_encoding = [[NSUserDefaults standardUserDefaults] integerForKey:@"CQDirectChatEncoding"];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_userNicknameDidChange:) name:MVChatUserNicknameChangedNotification object:self.user];

		_watchRule = [[MVChatUserWatchRule alloc] init];
		_watchRule.nickname = self.user.nickname;

		[self.connection addChatUserWatchRule:_watchRule];

		_revealKeyboard = YES;
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

		_revealKeyboard = NO;
	}

	_active = [[state objectForKey:@"active"] boolValue];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQHistoryOnReconnect"]) {
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
	} else {
		_recentMessages = [[NSMutableArray alloc] init];
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	if (_watchRule)
		[self.connection removeChatUserWatchRule:_watchRule];

	[_tweetRetryArguments release];
	
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
		id sameKeys[] = {@"message", @"messagePlain", @"action", @"notice", @"highlighted", @"identifier", @"type", nil};
		NSMutableDictionary *newMessage = [[NSMutableDictionary alloc] initWithKeys:sameKeys fromDictionary:message];

		if ([[newMessage objectForKey:@"message"] isEqual:[newMessage objectForKey:@"messagePlain"]])
			[newMessage removeObjectForKey:@"messagePlain"];

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

	chatInputBar.tintColor = [CQColloquyApplication sharedApplication].tintColor;

	NSString *capitalizationBehavior = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQChatAutocapitalizationBehavior"];
	chatInputBar.autocapitalizationType = ([capitalizationBehavior isEqualToString:@"Sentences"] ? UITextAutocapitalizationTypeSentences : UITextAutocapitalizationTypeNone);

	if (_pendingPreviousSessionComponents.count) {
		[transcriptView addPreviousSessionComponents:_pendingPreviousSessionComponents];

		[_pendingPreviousSessionComponents release];
		_pendingPreviousSessionComponents = nil;
	}

	if (_pendingComponents.count) {
		[transcriptView addComponents:_pendingComponents animated:NO];

		[_pendingComponents removeAllObjects];
	}
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	_active = YES;

	if (_pendingComponents.count) {
		[transcriptView addComponents:_pendingComponents animated:NO];

		[_pendingComponents removeAllObjects];
	}

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

	if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
		[[CQColloquyApplication sharedApplication] hideTabBarWithTransition:YES];
}

- (void) viewDidAppear:(BOOL) animated {
	[super viewDidAppear:animated];

	[transcriptView performSelector:@selector(flashScrollIndicators) withObject:nil afterDelay:0.1];

	if (_unreadHighlightedMessages)
		[CQChatController defaultController].totalImportantUnreadCount -= _unreadHighlightedMessages;

	if (_unreadMessages && self.user)
		[CQChatController defaultController].totalImportantUnreadCount -= _unreadMessages;

	_unreadMessages = 0;
	_unreadHighlightedMessages = 0;

	if (_revealKeyboard) {
		_revealKeyboard = NO;
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

	if ([self isMemberOfClass:[CQDirectChatController class]])
		[[CQColloquyApplication sharedApplication] showTabBarWithTransition:YES];
}

- (void) viewDidDisappear:(BOOL) animated {
	[super viewDidDisappear:animated];

	[chatInputBar resignFirstResponder];

	_allowEditingToEnd = NO;
}

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation) toInterfaceOrientation duration:(NSTimeInterval) duration {
	if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation))
		[[CQColloquyApplication sharedApplication] hideTabBarWithTransition:NO];
	else [[CQColloquyApplication sharedApplication] showTabBarWithTransition:NO];

	if ([chatInputBar isFirstResponder])
		[self _moveInputFieldForOrientation:toInterfaceOrientation];
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
		if (!commands) commands = [[NSArray alloc] initWithObjects:@"/me", @"/msg", @"/nick", @"/away", @"/say", @"/raw", @"/quote", @"/join", @"/quit", @"/disconnect", @"/query", @"/part", @"/notice", @"/umode", @"/globops", @"/whois", @"/dcc", @"/google", @"/wikipedia", @"/amazon", @"/browser", @"/url", @"/clear", @"/nickserv", @"/chanserv", @"/help", @"/faq", @"/search", @"/tweet", @"/ipod", @"/itunes", @"/music", @"/squit", nil];

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
				if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CQGraphicalEmoticons"])
					[completions addObject:[emoticon stringBySubstitutingEmoticonsForEmoji]];
				else [completions addObject:emoticon];
			}

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

	if ([text hasPrefix:@"/"] && ![text hasPrefix:@"//"] && text.length > 1) {
		static NSArray *commandsNotRequiringConnection;
		if (!commandsNotRequiringConnection)
			commandsNotRequiringConnection = [[NSArray alloc] initWithObjects:@"google", @"wikipedia", @"amazon", @"browser", @"url", @"connect", @"reconnect", @"clear", @"help", @"faq", @"search", @"tweet", nil];

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
		if ([text hasPrefix:@"/"] && text.length > 1)
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

	return [[CQColloquyApplication sharedApplication] openURL:url usingBuiltInBrowser:openWithBrowser withBrowserDelegate:self];
}

- (BOOL) _handleURLCommandWithArguments:(NSString *) arguments preferBuiltInBrowser:(BOOL) preferBrowser {
	NSScanner *scanner = [NSScanner scannerWithString:arguments];
	NSString *urlString = nil;

	[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&urlString];

	if (!preferBrowser && !urlString.length)
		return NO;

	if ([arguments isCaseInsensitiveEqualToString:@"last"])
		urlString = @"about:last";

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
	[_pendingComponents removeAllObjects];

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

- (BOOL) handleMusicCommandWithArguments:(NSString *) arguments {
	if (!NSClassFromString(@"MPMusicPlayerController") || !NSClassFromString(@"MPMediaItem"))
		return NO;

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

	[_target sendMessage:message withEncoding:self.encoding asAction:YES];

	NSData *messageData = [message dataUsingEncoding:self.encoding allowLossyConversion:YES];
	[self addMessage:messageData fromUser:self.connection.localUser asAction:YES withIdentifier:[NSString locallyUniqueString]];

	return YES;
}

- (BOOL) handleIpodCommandWithArguments:(NSString *) arguments {
	return [self handleMusicCommandWithArguments:arguments];
}

- (BOOL) handleItunesCommandWithArguments:(NSString *) arguments {
	return [self handleMusicCommandWithArguments:arguments];
}

- (BOOL) handleSquitCommandWithArguments:(NSString *) arguments {
	if (self.connection.directConnection)
		return NO;

	[self.connection sendRawMessageImmediatelyWithComponents:@"SQUIT :", arguments, nil];

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

- (void) _handleSearchForURL:(NSString *) urlFormatString withQuery:(NSString *) query {
	NSString *urlString = [NSString stringWithFormat:urlFormatString, [query stringByEncodingIllegalURLCharacters]];
	NSURL *url = [NSURL URLWithString:urlString];
	[self _openURL:url preferBuiltInBrowser:NO];
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

- (BOOL) handleHelpCommandWithArguments:(NSString *) arguments {
	NSString *urlString = nil;

	if ( [arguments hasCaseInsensitiveSubstring:@"join"] ) urlString = @"http://colloquy.info/project/wiki/MobileFAQs#HowdoIjoinanewchatroommessageauser";
	else if ( [arguments hasCaseInsensitiveSubstring:@"background"] ) urlString = @"http://colloquy.info/project/wiki/MobileFAQs#CanIrunMobileColloquyinthebackground";
	else if ( [arguments hasCaseInsensitiveSubstring:@"setting"] ) urlString = @"http://colloquy.info/project/wiki/MobileFAQs#HowdoIchangethedefaultsettings";
	else if ( [arguments hasCaseInsensitiveSubstring:@"command"] ) urlString = @"http://colloquy.info/project/wiki/MobileFAQs#Whatcommandsaresupported";
	else if ( [arguments hasCaseInsensitiveSubstring:@"topic"] ) urlString = @"http://colloquy.info/project/wiki/MobileFAQs#HowdoIchangethetopic";
	else if ( [arguments hasCaseInsensitiveSubstring:@"other"] ) urlString = @"http://colloquy.info/project/wiki/MobileFAQs#HowdoIgethelpforsomethingthatisntlistedhere";
	else if ( [arguments hasCaseInsensitiveSubstring:@"bug"] ) urlString = @"http://colloquy.info/project/wiki/MobileFAQs#HowdoIreportabug";
	else if ( [arguments hasCaseInsensitiveSubstring:@"style"] || [arguments hasCaseInsensitiveSubstring:@"theme"] ) urlString = @"http://colloquy.info/project/wiki/MobileFAQs#HowdoIchangethewaymessageslook";
	else if ( [arguments hasCaseInsensitiveSubstring:@"completion"] || [arguments hasCaseInsensitiveSubstring:@"popup"] ) urlString = @"http://colloquy.info/project/wiki/MobileFAQs#Howdothecompletionpopupswork";
	else urlString = @"http://colloquy.info/project/wiki/MobileFAQs";

	NSURL *url = [NSURL URLWithString:urlString];

	[self _openURL:url preferBuiltInBrowser:NO];

	return YES;
}

- (BOOL) handleFaqCommandWithArguments:(NSString *) arguments {
	[self handleHelpCommandWithArguments:arguments];

	return YES;
}

- (BOOL) handleSearchCommandWithArguments:(NSString *) arguments {
	NSString *urlString = @"http://searchirc.com/search.php?F=partial&I=%@&T=both&N=all&M=min&C=5&PER=20";

	[self _handleSearchForURL:urlString withQuery:arguments];

	return YES;
}

#pragma mark -

- (BOOL) handleTweetCommandWithArguments:(NSString *) arguments {
	NSString *username = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQTwitterUsername"];
	NSString *password = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQTwitterPassword"];

	id old = _tweetRetryArguments;
	_tweetRetryArguments = [arguments copy];
	[old release];

	if (!arguments.length)
		return YES;

	BOOL success = YES;
	BOOL showSettings = NO;
	BOOL allowRetry = YES;

    UIAlertView *alert = [[UIAlertView alloc] init];
	alert.delegate = self;

	alert.cancelButtonIndex = [alert addButtonWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title")];

	if (!username.length) {
		alert.title = NSLocalizedString(@"No Twitter Username", "No Twitter username alert title");
		alert.message = NSLocalizedString(@"You need to enter a Twitter username in Colloquy's Settings.", "No Twitter username alert message");
		showSettings = YES;
		success = NO;
	}

	if (success && !password.length) {
		alert.title = NSLocalizedString(@"No Twitter Password", "No Twitter password alert title");
		alert.message = NSLocalizedString(@"You need to enter a Twitter password in Colloquy's Settings.", "No Twitter password alert message");
		showSettings = YES;
		success = NO;
	}

	if (success && arguments.length > 140) {
		alert.title = NSLocalizedString(@"Tweet Too Long", "Tweet too long title");
		alert.message = [NSString stringWithFormat:NSLocalizedString(@"Your tweet was %d characters over the limit.", "Your tweet was %d characters over the limit alert message"), (arguments.length - 140)];
		allowRetry = NO;
		success = NO;
	}

	if (success) {
		NSString *twitterURL = [NSString stringWithFormat:@"https://%@:%@@twitter.com/statuses/update.json", username, password];
		NSString *tweet = [@"source=mobilecolloquy&status=" stringByAppendingString:[_tweetRetryArguments stringByEncodingIllegalURLCharacters]];
		NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:twitterURL] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.];

		[request setHTTPMethod:@"POST"];
		[request setHTTPBody:[tweet dataUsingEncoding:NSUTF8StringEncoding]];

		success = NO;

		[CQColloquyApplication sharedApplication].networkActivityIndicatorVisible = YES;

		NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:NULL];
		NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

		[CQColloquyApplication sharedApplication].networkActivityIndicatorVisible = NO;

		if (response.length) {
			if ([response hasCaseInsensitiveSubstring:@"Could not authenticate you"]) {
				alert.title = NSLocalizedString(@"Couldn't Authenticate with Twitter", "Could not authenticate title");
				alert.message = NSLocalizedString(@"Make sure your Twitter username and password are correct.", "Make sure your Twitter username and password are correct alert message");
				showSettings = YES;
			} else if ([response hasCaseInsensitiveSubstring:@"503 Service Temporarily Unavailable"] || [response hasCaseInsensitiveSubstring:@"403 Forbidden"]) {
				alert.title = NSLocalizedString(@"Twitter Unavailable", "Twitter Temporarily Unavailable title");
				alert.message = NSLocalizedString(@"Unable to send tweet because Twitter is temporarily unavailable.", "Unable to send tweet because Twitter is temporarily unavailable alert message");
			} else success = YES;
		} else {
			alert.title = NSLocalizedString(@"Unable To Send Tweet", "Unable to send tweet alert title");
			alert.message = NSLocalizedString(@"Unable to send the tweet to Twitter.", "Unable to submit the tweet to Twitter alert message");
		}

		if (allowRetry && !showSettings) {
			alert.tag = TweetRetryAlertTag;
			[alert addButtonWithTitle:NSLocalizedString(@"Retry", @"Retry alert button title")];
		}

		[request release];
		[response release];
	}

	if (showSettings) {
		alert.tag = TweetSettingsAlertTag;
		[alert addButtonWithTitle:NSLocalizedString(@"Settings", @"Settings alert button title")];
	}

	if (success) {
		[_tweetRetryArguments release];
		_tweetRetryArguments = nil;
	} else [alert show];

	[alert release];

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

- (BOOL) handleDccCommandWithArguments:(NSString *) arguments {
	if (arguments.length == 0) {
		return NO;
	}

	NSString *nick = [[arguments componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] objectAtIndex:0];
	MVChatUser *user = [[self.connection chatUsersWithNickname:nick] anyObject];
	[[CQChatController defaultController] showFilePickerWithUser:user];

	return YES;
}

#pragma mark -

- (void) browserViewController:(CQBrowserViewController *) browserViewController sendURL:(NSURL *) url {
	NSString *existingText = chatInputBar.textField.text;
	if (existingText.length)
		chatInputBar.textField.text = [NSString stringWithFormat:@"%@ %@", existingText, url.absoluteString];
	else chatInputBar.textField.text = url.absoluteString;

	[browserViewController close:nil];
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
	[self _moveInputFieldForOrientation:self.interfaceOrientation];

	[transcriptView scrollToBottomAnimated:YES];

	_showingKeyboard = YES;
}

- (void) keyboardWillHide:(NSNotification *) notification {
	if (!_showingKeyboard)
		return;

	CGPoint beginCenterPoint = CGPointZero;
	CGPoint endCenterPoint = CGPointZero;

	[[[notification userInfo] objectForKey:UIKeyboardCenterBeginUserInfoKey] getValue:&beginCenterPoint];
	[[[notification userInfo] objectForKey:UIKeyboardCenterEndUserInfoKey] getValue:&endCenterPoint];

	// Keyboard is sliding horizontal, so don't change.
	if (beginCenterPoint.y == endCenterPoint.y)
		return;

	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.3];

	containerView.frame = self.view.bounds;

	[UIView commitAnimations];

	[transcriptView scrollToBottomAnimated:YES];

	_showingKeyboard = NO;
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

	[self _addPendingComponent:message];

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
	NSParameterAssert(message != nil);

	if (!chatMessageProcessingQueue) {
		chatMessageProcessingQueue = [[NSOperationQueue alloc] init];
		chatMessageProcessingQueue.maxConcurrentOperationCount = 1;
	}

	CQProcessChatMessageOperation *operation = [[CQProcessChatMessageOperation alloc] initWithMessageInfo:message];
	operation.highlightNickname = self.connection.nickname;
	operation.encoding = self.encoding;

	operation.target = self;
	operation.action = @selector(_messageProcessed:);

	[chatMessageProcessingQueue addOperation:operation];

	[operation release];
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
		[self.connection connect];

	if (alertView.tag == TweetRetryAlertTag)
		[self performSelector:@selector(handleTweetCommandWithArguments:) withObject:_tweetRetryArguments afterDelay:0.];

	if (alertView.tag == TweetSettingsAlertTag)
		[[CQColloquyApplication sharedApplication] launchSettings];
}

#pragma mark -

- (void) _moveInputFieldForOrientation:(UIInterfaceOrientation) interfaceOrientation {
	BOOL landscape = UIInterfaceOrientationIsLandscape(interfaceOrientation);

	// If [UIKeyboard defaultSizeForOrientation:] is ever documented, use that instead of hardcoding values.
	CGRect keyboardBounds = (landscape ? CGRectMake(0, 0, 320, 216) : CGRectMake(0, 0, 480, 162));

	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:0.3];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseOut];

	CGFloat shift = ([CQColloquyApplication sharedApplication].showingTabBar && !landscape ? keyboardBounds.size.height + 5 : keyboardBounds.size.height - 55); // Tab bar height

	CGRect frame = containerView.frame;
	frame.size.height = (self.view.bounds.size.height - shift);
	containerView.frame = frame;

	[UIView commitAnimations];
}

- (void) _showCantSendMessagesWarningForCommand:(BOOL) command {
	UIAlertView *alert = [[UIAlertView alloc] init];
	alert.delegate = self;

	if (command) alert.title = NSLocalizedString(@"Can't Send Command", @"Can't send command alert title");
	else alert.title = NSLocalizedString(@"Can't Send Message", @"Can't send message alert title");

	if (self.connection.status == MVChatConnectionConnectingStatus) {
		alert.message = NSLocalizedString(@"You are currently connecting,\ntry sending again soon.", @"Can't send message to user because server is connecting alert message");
	} else if (!self.connection.connected) {
		alert.tag = ReconnectAlertTag;
		alert.message = NSLocalizedString(@"You are currently disconnected,\nreconnect and try again.", @"Can't send message to user because server is disconnected alert message");
		[alert addButtonWithTitle:NSLocalizedString(@"Connect", @"Connect alert button title")];
	} else if (self.user.status != MVChatUserAvailableStatus && self.user.status != MVChatUserAwayStatus) {
		alert.message = NSLocalizedString(@"The user is not connected.", @"Can't send message to user because they are disconnected alert message");
	} else {
		[alert release];
		return;
	}

	alert.cancelButtonIndex = [alert addButtonWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss alert button title")];

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

	[self _updateRightBarButtonItemAnimated:YES];
}

- (void) _didDisconnect:(NSNotification *) notification {
	[self addEventMessage:NSLocalizedString(@"Disconnected from the server.", "Disconnect from the server event message") withIdentifier:@"disconnected"];

	[self _updateRightBarButtonItemAnimated:YES];
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

	if (self.connection.connected)
		item = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"info.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(showUserInformation)];
	else item = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Connect", "Connect button title") style:UIBarButtonItemStyleDone target:self.connection action:@selector(connect)];

	[self.navigationItem setRightBarButtonItem:item animated:animated];

	[item release];
}

- (void) _processMessageData:(NSData *) messageData target:(id) target action:(SEL) action userInfo:(id) userInfo {
	if (!messageData) {
		if (target && action)
			[target performSelectorOnMainThread:action withObject:nil waitUntilDone:NO];
		return;
	}

	if (!chatMessageProcessingQueue) {
		chatMessageProcessingQueue = [[NSOperationQueue alloc] init];
		chatMessageProcessingQueue.maxConcurrentOperationCount = 1;
	}

	CQProcessChatMessageOperation *operation = [[CQProcessChatMessageOperation alloc] initWithMessageData:messageData];
	operation.encoding = self.encoding;

	operation.target = target;
	operation.action = action;
	operation.userInfo = userInfo;

	[chatMessageProcessingQueue addOperation:operation];

	[operation release];
}

- (void) _addPendingComponent:(id) component {
	if (!_pendingComponents)
		_pendingComponents = [[NSMutableArray alloc] init];

	BOOL hadPendingComponents = _pendingComponents.count;

	[_pendingComponents addObject:component];

	while (_pendingComponents.count > 300)
		[_pendingComponents removeObjectAtIndex:0];

	if (!transcriptView || !_active)
		return;

	if (!hadPendingComponents)
		[self performSelector:@selector(_addPendingComponents) withObject:nil afterDelay:0.1];
}

- (void) _addPendingComponents {
	[transcriptView addComponents:_pendingComponents animated:YES];

	[_pendingComponents removeAllObjects];
}

- (void) _messageProcessed:(CQProcessChatMessageOperation *) operation {
	NSMutableDictionary *message = operation.processedMessageInfo;
	BOOL highlighted = [[message objectForKey:@"highlighted"] boolValue];

	MVChatUser *user = [message objectForKey:@"user"];
	if (!user.localUser && !_active && self.available) {
		if (highlighted) ++_unreadHighlightedMessages;
		else ++_unreadMessages;

		if (self.user || highlighted)
			++[CQChatController defaultController].totalImportantUnreadCount;
	}

	static BOOL vibrateOnHighlight;
	static BOOL soundOnHighlight;
	static BOOL vibrateOnPrivateMessage;
	static BOOL soundOnPrivateMessage;

	static BOOL firstTime = YES;
	if (firstTime) {
		firstTime = NO;

		vibrateOnHighlight = [[NSUserDefaults standardUserDefaults] boolForKey:@"CQVibrateOnHighlight"];
		soundOnHighlight = ![[[NSUserDefaults standardUserDefaults] stringForKey:@"CQSoundOnHighlight"] isEqualToString:@"None"];
		vibrateOnPrivateMessage = [[NSUserDefaults standardUserDefaults] boolForKey:@"CQVibrateOnPrivateMessage"];
		soundOnPrivateMessage = ![[[NSUserDefaults standardUserDefaults] stringForKey:@"CQSoundOnPrivateMessage"] isEqualToString:@"None"];
	}

	BOOL directChat = [self isMemberOfClass:[CQDirectChatController class]];

	if (!user.localUser && directChat) {
		if (vibrateOnPrivateMessage)
			[CQSoundController vibrate];

		if (soundOnPrivateMessage) {
			static CQSoundController *privateMessageSound;

			if (!privateMessageSound) {
				NSString *alert = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQSoundOnPrivateMessage"];
				privateMessageSound = [[CQSoundController alloc] initWithSoundNamed:alert];
			}

			[privateMessageSound playAlert];
		}
	}

	if (highlighted && self.available) {
		if (vibrateOnHighlight)
			[CQSoundController vibrate];

		if (soundOnHighlight && (!directChat || (directChat && !soundOnPrivateMessage))) {
			static CQSoundController *highlightSound;

			if (!highlightSound) {
				NSString *alert = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQSoundOnHighlight"];
				highlightSound = [[CQSoundController alloc] initWithSoundNamed:alert];
			}

			[highlightSound playAlert];
		}
	}

	if (!_recentMessages)
		_recentMessages = [[NSMutableArray alloc] init];
	[_recentMessages addObject:message];

	while (_recentMessages.count > 10)
		[_recentMessages removeObjectAtIndex:0];

	[self _addPendingComponent:message];

	if (!user.localUser)
		[[NSNotificationCenter defaultCenter] postNotificationName:CQChatViewControllerRecentMessagesUpdatedNotification object:self];
}
@end
