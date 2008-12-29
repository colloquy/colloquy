#import "CQDirectChatController.h"

#import "CQChatController.h"
#import "CQChatInputBar.h"
#import "CQChatInputField.h"
#import "CQChatTableCell.h"
#import "CQStyleView.h"
#import "NSDictionaryAdditions.h"
#import "NSScannerAdditions.h"
#import "NSStringAdditions.h"

#import <AGRegex/AGRegex.h>

#include <AudioToolbox/AudioToolbox.h>

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatUser.h>
#import <ChatCore/MVChatUserWatchRule.h>

@interface CQDirectChatController (CQDirectChatControllerPrivate)
- (void) _showCantSendMessagesWarning;
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
		_encoding = [[NSUserDefaults standardUserDefaults] integerForKey:@"CQDirectChatEncoding"];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_userNicknameDidChange:) name:MVChatUserNicknameChangedNotification object:self.user];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_didConnect:) name:MVChatConnectionDidConnectNotification object:self.connection];

		_watchRule = [[MVChatUserWatchRule alloc] init];
		_watchRule.nickname = self.user.nickname;

		[self.connection addChatUserWatchRule:_watchRule];
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
	}

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

	if ([CQChatController defaultController].visibleViewController == self)
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

- (void) viewDidLoad {
	[super viewDidLoad];

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
	_active = YES;
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
	return YES;
}

- (NSArray *) chatInputBar:(CQChatInputBar *) chatInputBar completionsForWordWithPrefix:(NSString *) word inRange:(NSRange) range {
	NSMutableArray *completions = [[NSMutableArray alloc] init];

	NSString *nickname = (range.location ? self.user.nickname : [self.user.nickname stringByAppendingString:@":"]);
	if ([nickname hasCaseInsensitivePrefix:word] && ![nickname isEqualToString:word])
		[completions addObject:[nickname stringByAppendingString:@" "]];

	nickname = (range.location ? self.connection.nickname : [self.connection.nickname stringByAppendingString:@":"]);
	if ([nickname hasCaseInsensitivePrefix:word] && ![nickname isEqualToString:word])
		[completions addObject:[nickname stringByAppendingString:@" "]];

	if ([word hasPrefix:@"/"]) {
		static NSArray *commands;
		if (!commands) commands = [[NSArray alloc] initWithObjects:@"/me", @"/msg", @"/nick", @"/away", @"/say", @"/raw", @"/quote", @"/join", @"/quit", @"/disconnect", @"/query", @"/umode", @"/globops", nil];

		for (NSString *command in commands) {
			if ([command hasCaseInsensitivePrefix:word] && ![command isCaseInsensitiveEqualToString:word])
				[completions addObject:[command stringByAppendingString:@" "]];
			if (completions.count >= 10)
				break;
		}
	}

	if (completions.count < 10 && ([word containsTypicalEmoticonCharacters] || [word hasCaseInsensitivePrefix:@"x"] || [word hasCaseInsensitivePrefix:@"o"] || [word hasCaseInsensitivePrefix:@"~"])) {
		static NSArray *emoticons;
		if (!emoticons) emoticons = [[NSArray alloc] initWithObjects:@":) ", @":( ", @":P ", @":D ", @":o ", @":O ", @":[ ", @":-* ", @";) ", @";P ", @";-* ", @">< ", @">:( ", @">=( ", @">:) ", @">=) ", @"<3 ", @"</3 ", @"=) ", @"=( ", @"=P ", @"=D ", @"=o ", @"=O ", @"=[ ", @"=-* ", @"x.x ", @"XD ", @"O:) ", @"O=) ", @"^-^ ", @"-_- ", @"-_-' ", @"~<:) ", nil];

		for (NSString *emoticon in emoticons) {
			if ([emoticon hasCaseInsensitivePrefix:word])
				[completions addObject:[emoticon stringBySubstitutingEmoticonsForEmoji]];
			if (completions.count >= 10)
				break;
		}
	}

	if (completions.count < 10) {
		for (MVChatRoom *room in self.connection.knownChatRooms) {
			if ([room.name hasCaseInsensitivePrefix:word] && ![room.name isCaseInsensitiveEqualToString:word])
				[completions addObject:[room.name stringByAppendingString:@" "]];
			if (completions.count >= 10)
				break;
		}
	}

	return [completions autorelease];
}

- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar sendText:(NSString *) text {
	if (!self.available) {
		[self _showCantSendMessagesWarning];
		return NO;
	}

	_didSendRecently = YES;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(resetDidSendRecently) object:nil];
	[self performSelector:@selector(resetDidSendRecently) withObject:nil afterDelay:0.5];

	if ([text hasPrefix:@"/"] && ![text hasPrefix:@"//"]) {
		// Send as a command.
		NSScanner *scanner = [NSScanner scannerWithString:text];
		[scanner setCharactersToBeSkipped:nil];

		NSString *command = nil;
		NSString *arguments = nil;

		[scanner scanString:@"/" intoString:nil];
		[scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&command];
		[scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] maxLength:1 intoString:NULL];

		arguments = [text substringFromIndex:scanner.scanLocation];

		[_target sendCommand:command withArguments:arguments withEncoding:self.encoding];
	} else {
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

- (BOOL) transcriptView:(CQChatTranscriptView *) transcriptView handleOpenURL:(NSURL *) url {
	if ((![url.scheme isEqualToString:@"irc"] && ![url.scheme isEqualToString:@"ircs"]) || url.host.length)
		return NO;

	NSString *target = @"";
	if (url.fragment.length) target = [@"#" stringByAppendingString:url.fragment];
	else if (url.path.length > 1) target = url.path;

	url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@/%@", url.scheme, self.connection.server, target]];

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

	endCenterPoint = [self.view.window convertPoint:endCenterPoint toView:self.view];

	BOOL previouslyShowingKeyboard = (chatInputBar.center.y != (self.view.bounds.size.height - (chatInputBar.bounds.size.height / 2.)));
	if (!previouslyShowingKeyboard) {
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.25];

#if defined(TARGET_IPHONE_SIMULATOR) && TARGET_IPHONE_SIMULATOR
		[UIView setAnimationDelay:0.025];
#else
		[UIView setAnimationDelay:0.15];
#endif
	}

	CGRect bounds = chatInputBar.bounds;
	CGPoint center = chatInputBar.center;
	CGFloat keyboardTop = MAX(chatInputBar.bounds.size.height, endCenterPoint.y - (keyboardBounds.size.height / 2.));
	center.y = keyboardTop - (bounds.size.height / 2.);
	chatInputBar.center = center;

	bounds = transcriptView.bounds;
	bounds.size.height = keyboardTop - chatInputBar.bounds.size.height;
	transcriptView.bounds = bounds;

	center = transcriptView.center;
	center.y = (bounds.size.height / 2.);
	transcriptView.center = center;

	if (!previouslyShowingKeyboard)
		[UIView commitAnimations];
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
		urlRegex = [[AGRegex alloc] initWithPattern:@"(?P<room>\\B(?<!&amp;)#(?![\\da-fA-F]{6}\\b|\\d{1,3}\\b)[\\w-_.+&;#]{2,}\\b)|(?P<url>(?:[a-zA-Z][a-zA-Z0-9+.-]{2,}:(?://){0,1}|www\\.)[\\p{L}\\p{N}$\\-_+*'=\\|/\\\\(){}[\\]%@&#~,:;.!?]{4,}[\\p{L}\\p{N}$\\-_+*=\\|/\\\\({%@&;#~])|(?P<email>[\\p{L}\\p{N}.+\\-_]+@(?:[\\p{L}\\-_]+\\.)+[\\w]{2,})" options:AGRegexCaseInsensitive];

	AGRegexMatch *match = [urlRegex findInString:string range:*textRange];
	while (match) {
		NSString *room = [match groupNamed:@"room"];
		NSString *url = [match groupNamed:@"url"];
		NSString *email = [match groupNamed:@"email"];

		NSString *linkHTMLString = nil;
		if (room.length) {
			linkHTMLString = [NSString stringWithFormat:@"<a href=\"irc:///%@\">%1$@</a>", room];
		} else if (url.length) {
			NSString *fullURL = ([url hasPrefix:@"www."] ? [@"http://" stringByAppendingString:url] : url);
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

- (void) _showCantSendMessagesWarning {
	UIAlertView *alert = [[UIAlertView alloc] init];
	alert.delegate = self;
	alert.title = NSLocalizedString(@"Can't Send Message", @"Can't send message alert title");

	if (!self.connection.connected) {
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
