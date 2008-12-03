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

- (void) viewWillAppear:(BOOL) animated {
	[super viewWillAppear:animated];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void) viewDidAppear:(BOOL) animated {
	[super viewDidAppear:animated];

	_unreadMessages = 0;
	_unreadHighlightedMessages = 0;
	_active = YES;
}

- (void) viewWillDisappear:(BOOL) animated {
	_viewDisappearing = YES;

	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];

	[super viewWillDisappear:animated];
}

- (void) viewDidDisappear:(BOOL) animated {
	[super viewDidDisappear:animated];

	[chatInputBar resignFirstResponder];

	_viewDisappearing = NO;
}

#pragma mark -

- (BOOL) chatInputBarShouldEndEditing:(CQChatInputBar *) chatInputBar {
	if (_viewDisappearing)
		return YES;
	return NO;
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

- (BOOL) chatInput:(CQChatInputBar *) chatInputBar sendText:(NSString *) text {
	[_target sendMessage:text withEncoding:NSUTF8StringEncoding asAction:NO];

	NSData *messageData = [text dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
	[self addMessageToDisplay:messageData fromUser:self.connection.localUser asAction:NO withIdentifier:@"" andType:CQChatMessageNormalType];

	return YES;
}

#pragma mark -

- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier andType:(CQChatMessageType) type;
{
	[self addMessageToDisplay:message fromUser:user withAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:action] forKey:@"action"] withIdentifier:identifier andType:type];
}

- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user withAttributes:(NSDictionary *) msgAttributes withIdentifier:(NSString *) identifier andType:(CQChatMessageType) type {
	[transcriptView addMessageToDisplay:message fromUser:user withAttributes:msgAttributes withIdentifier:identifier andType:type];
}
@end
