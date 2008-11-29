#import "CQDirectChatController.h"

#import "CQChatController.h"
#import "CQChatInputField.h"
#import "CQChatTableCell.h"
#import "CQInputBarView.h"
#import "CQStyleView.h"

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatUser.h>

@implementation CQDirectChatController
- (id) initWithTarget:(id) target {
	if (!(self = [super init]))
		return nil;

	_target = [target retain];

	return self;
}

- (void) dealloc {
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

- (void) viewDidAppear:(BOOL) animated {
	_unreadMessages = 0;
	_unreadHighlightedMessages = 0;
	_active = YES;
}

- (void) viewWillDisappear:(BOOL) animated {
	_active = NO;
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
