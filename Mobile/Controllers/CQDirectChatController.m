#import "CQDirectChatController.h"

#import "CQChatController.h"
#import "CQChatInputField.h"
#import "CQChatTableCell.h"
#import "CQChatInputBar.h"
#import "CQStyleView.h"
#import "NSScannerAdditions.h"

#import <AGRegex/AGRegex.h>

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatUser.h>
#import <ChatCore/MVChatUserWatchRule.h>

@interface CQDirectChatController (CQDirectChatControllerPrivate)
- (void) _showCantSendMessagesWarning;
@end

#pragma mark -

@implementation CQDirectChatController
- (id) initWithTarget:(id) target {
	if (!(self = [super initWithNibName:@"ChatView" bundle:nil]))
		return nil;

	_target = [target retain];

	if (self.user) {
		_encoding = [[NSUserDefaults standardUserDefaults] integerForKey:@"CQDirectChatEncoding"];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_userNicknameDidChange:) name:MVChatUserNicknameChangedNotification object:self.user];

		_watchRule = [[MVChatUserWatchRule alloc] init];
		_watchRule.nickname = self.user.nickname;

		[self.connection addChatUserWatchRule:_watchRule];
	}

	// Load the view now so it is ready to add messages.
	self.view;

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	if (_watchRule)
		[self.connection removeChatUserWatchRule:_watchRule];

	[_watchRule release];
	[_recentMessages release];
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

	transcriptView.stripMessageFormatting = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageFormatting"];
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

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
	[transcriptView scrollToBottom];
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
		[self addMessage:messageData fromUser:self.connection.localUser asAction:NO withIdentifier:@"" andType:CQChatMessageNormalType];
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

- (NSStringEncoding) transcriptView:(CQChatTranscriptView *) transcriptView encodingForMessageData:(NSData *) message {
	return self.encoding;
}

- (NSArray *) highlightWordsForTranscriptView:(CQChatTranscriptView *) transcriptView {
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
	return [highlightWords autorelease];
}

- (void) transcriptView:(CQChatTranscriptView *) transcriptView highlightedMessageWithWord:(NSString *) highlightWord {
	if (!_active) {
		++_unreadHighlightedMessages;
		++[CQChatController defaultController].totalImportantUnreadCount;
	}
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

		[UIView setAnimationDelay:0.05];
		[UIView setAnimationDuration:0.25];
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

- (void) addMessage:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier andType:(CQChatMessageType) type;
{
	NSMutableDictionary *info = [[NSMutableDictionary alloc] init];

	if (message) [info setObject:message forKey:@"message"];
	if (user) [info setObject:user forKey:@"user"];
	if (identifier) [info setObject:identifier forKey:@"identifier"];
	[info setObject:[NSNumber numberWithBool:action] forKey:@"action"];
	[info setObject:[NSNumber numberWithUnsignedLong:type] forKey:@"type"];

	[self addMessage:info];

	[info release];
}

- (void) addMessage:(NSDictionary *) info {
	if (!_recentMessages)
		_recentMessages = [[NSMutableArray alloc] init];

	MVChatUser *user = [info objectForKey:@"user"];

	if (!user.localUser) {
		if (!_active) {
			++_unreadMessages;
			if (self.user)
				++[CQChatController defaultController].totalImportantUnreadCount;
		}

		[_recentMessages addObject:info];
		if (_recentMessages.count > 5)
			[_recentMessages removeObjectAtIndex:0];
	}

	[transcriptView addMessage:info];
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
@end
