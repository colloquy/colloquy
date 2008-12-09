#import "CQDirectChatController.h"

#import "CQChatController.h"
#import "CQChatInputField.h"
#import "CQChatTableCell.h"
#import "CQChatInputBar.h"
#import "CQStyleView.h"

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatUser.h>

@implementation CQDirectChatController
- (id) initWithTarget:(id) target {
	if (!(self = [super initWithNibName:@"ChatView" bundle:nil]))
		return nil;

	_target = [target retain];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_recentMessages release];
	[_pendingMessages release];
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

#pragma mark -

- (NSUInteger) unreadMessages {
	return _unreadMessages;
}

- (NSUInteger) unreadHighlightedMessages {
	return _unreadHighlightedMessages;
}

#pragma mark -

- (void) viewDidLoad {
	[super viewDidLoad];

	[transcriptView addMessages:_pendingMessages];

	[_pendingMessages release];
	_pendingMessages = nil;
}

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void) viewDidAppear:(BOOL) animated {
	[super viewDidAppear:animated];

	[transcriptView flashScrollIndicators];

	_unreadMessages = 0;
	_unreadHighlightedMessages = 0;
	_active = YES;
}

- (void) viewWillDisappear:(BOOL) animated {
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

#pragma mark -

- (void) chatInputBarDidBeginEditing:(CQChatInputBar *) chatInputBar {
	[transcriptView scrollToBottom];
}

- (BOOL) chatInputBarShouldEndEditing:(CQChatInputBar *) chatInputBar {
	if (_allowEditingToEnd)
		return YES;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkTranscriptViewForBecomeFirstResponder) object:nil];
	[self performSelector:@selector(checkTranscriptViewForBecomeFirstResponder) withObject:nil afterDelay:0.4];

	return NO;
}

- (BOOL) chatInputBar:(CQChatInputBar *) chatInputBar sendText:(NSString *) text {
	_didSendRecently = YES;

	[_target sendMessage:text withEncoding:NSUTF8StringEncoding asAction:NO];

	NSData *messageData = [text dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
	[self addMessage:messageData fromUser:self.connection.localUser asAction:NO withIdentifier:@"" andType:CQChatMessageNormalType];

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(resetDidSendRecently) object:nil];
	[self performSelector:@selector(resetDidSendRecently) withObject:nil afterDelay:0.5];

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
		[UIView beginAnimations:@"CQDirectChatControllerKeyboardShowing" context:NULL];

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

	[UIView beginAnimations:@"CQDirectChatControllerKeyboardHiding" context:NULL];

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
		[_recentMessages addObject:info];
		if (_recentMessages.count > 5)
			[_recentMessages removeObjectAtIndex:0];
	}

	if (!transcriptView) {
		if (!_pendingMessages)
			_pendingMessages = [[NSMutableArray alloc] init];
		[_pendingMessages addObject:info];
		return;
	}

	[transcriptView addMessage:info];
}
@end
