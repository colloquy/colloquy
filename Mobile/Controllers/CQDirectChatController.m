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

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation) interfaceOrientation {
	return YES;
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

	CGFloat keyboardTop = endCenterPoint.y - (keyboardBounds.size.height / 2.);

	[UIView beginAnimations:@"CQDirectChatControllerKeyboardShowing" context:NULL];

	[UIView setAnimationDelay:0.05];
	[UIView setAnimationDuration:0.25];

	CGRect frame = chatInputBar.frame;
	frame.origin.y = keyboardTop - frame.size.height;
	chatInputBar.frame = frame;

	frame = transcriptView.frame;
	frame.size.height = keyboardTop - chatInputBar.frame.size.height;
	transcriptView.frame = frame;

	[UIView commitAnimations];
}

- (void) keyboardWillHide:(NSNotification *) notification {
	CGPoint endCenterPoint = CGPointZero;
	CGRect keyboardBounds = CGRectZero;

	[[[notification userInfo] objectForKey:UIKeyboardCenterEndUserInfoKey] getValue:&endCenterPoint];
	[[[notification userInfo] objectForKey:UIKeyboardBoundsUserInfoKey] getValue:&keyboardBounds];

	endCenterPoint = [self.view.window convertPoint:endCenterPoint toView:self.view];

	CGFloat keyboardTop = endCenterPoint.y - (keyboardBounds.size.height / 2.);

	[UIView beginAnimations:@"CQDirectChatControllerKeyboardHiding" context:NULL];

	[UIView setAnimationDuration:0.25];

	CGRect frame = chatInputBar.frame;
	frame.origin.y = keyboardTop - frame.size.height;
	chatInputBar.frame = frame;

	frame = transcriptView.frame;
	frame.size.height = keyboardTop - chatInputBar.frame.size.height;
	transcriptView.frame = frame;

	[UIView commitAnimations];
}

#pragma mark -

- (void) send:(id) sender {
	NSString *message = @"";
	[_target sendMessage:message withEncoding:NSUTF8StringEncoding asAction:NO];

	NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
	[self addMessageToDisplay:messageData fromUser:self.connection.localUser asAction:NO withIdentifier:@"" andType:CQChatMessageNormalType];

	[message release];
}

#pragma mark -

- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier andType:(CQChatMessageType) type;
{
	[self addMessageToDisplay:message fromUser:user withAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:action] forKey:@"action"] withIdentifier:identifier andType:type];
}

- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user withAttributes:(NSDictionary *) msgAttributes withIdentifier:(NSString *) identifier andType:(CQChatMessageType) type {
}
@end
