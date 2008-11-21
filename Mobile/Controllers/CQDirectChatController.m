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
	if( ! ( self = [super init] ) )
		return nil;

	_target = [target retain];

/*
	CGRect screenRect = [[UIScreen mainScreen] applicationFrame];
	_transcriptView = [[CQStyleView alloc] initWithFrame:CGRectMake(0., 0., screenRect.size.width, screenRect.size.height - 85.)];
	[_transcriptView setDelegate:self];
	[_transcriptView setAllowsRubberBanding:YES];
	[_transcriptView setBottomBufferHeight:0.];
*/
	return self;
}

- (void) dealloc {
	[_inputBarView release];
	[_inputField release];
	[_target release];
//	[_transcriptView release];
//	[_view release];
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

/*
- (void) setKeyboardVisible:(BOOL) visible animate:(BOOL) animate {
	if( visible == _keyboardVisible )
		return;

	_keyboardVisible = visible;

	NSMutableArray *animations = nil;
	if( animate ) animations = [[NSMutableArray alloc] initWithCapacity:3];

	CGRect startFrame;
	CGRect endFrame;

	// Create the start and end frames for the input bar view
	if( visible ) {
		startFrame = CGRectMake(0., [_view frame].size.height - [_inputBarView frame].size.height, [_inputBarView frame].size.width, [_inputBarView frame].size.height);
		endFrame = startFrame;
		endFrame.origin.y = [_view frame].size.height - [_keyboard frame].size.height - [_inputBarView frame].size.height;
	} else {
		startFrame = CGRectMake(0., [_view frame].size.height - [_inputBarView frame].size.height - [_keyboard frame].size.height, [_inputBarView frame].size.width, [_inputBarView frame].size.height);
		endFrame = startFrame;
		endFrame.origin.y = [_view frame].size.height - [_inputBarView frame].size.height;
	}

	if( animate ) {
		[_inputBarView setFrame:startFrame];

		UIFrameAnimation *inputBarAnimation = [[UIFrameAnimation alloc] initWithTarget:_inputBarView];
		[inputBarAnimation setStartFrame:startFrame];
		[inputBarAnimation setEndFrame:endFrame];
		[inputBarAnimation setSignificantRectFields:2]; // the y position of the rect

		[animations addObject:inputBarAnimation];

		[inputBarAnimation release];
	} else {
		[_inputBarView setFrame:endFrame];
	}

	// Create the start and end frames for the transcript view
	if( visible ) {
		startFrame = CGRectMake(0., 0., [_transcriptView frame].size.width, [_view frame].size.height - [_inputBarView frame].size.height);
		endFrame = startFrame;
		endFrame.size.height = [_view frame].size.height - [_inputBarView frame].size.height - [_keyboard frame].size.height;
	} else {
		startFrame = CGRectMake(0., 0., [_transcriptView frame].size.width, [_view frame].size.height - [_inputBarView frame].size.height - [_keyboard frame].size.height);
		endFrame = startFrame;
		endFrame.size.height = [_view frame].size.height - [_inputBarView frame].size.height;
	}

	if( animate ) {
		[_transcriptView setFrame:startFrame];

		UIFrameAnimation *transcriptAnimation = [[UIFrameAnimation alloc] initWithTarget:_transcriptView];
		[transcriptAnimation setStartFrame:startFrame];
		[transcriptAnimation setEndFrame:endFrame];
		[transcriptAnimation setSignificantRectFields:8]; // the height of the rect

		[transcriptAnimation setDelegate:self];

		[animations addObject:transcriptAnimation];

		[transcriptAnimation release];

		if( visible ) {
			CGPoint endBottomOffset = [_transcriptView bottomScrollOffset];
			endBottomOffset.y += startFrame.size.height;
			endBottomOffset.y -= endFrame.size.height;
			endBottomOffset.y = MAX(endBottomOffset.y, 0);

			UIScrollerScrollAnimation *transcriptScrollAnimation = [[UIScrollerScrollAnimation alloc] initWithTarget:_transcriptView];
			[transcriptScrollAnimation setOriginalOffset:[_transcriptView offset]];
			[transcriptScrollAnimation setTargetOffset:endBottomOffset];

			[animations addObject:transcriptScrollAnimation];

			[UIScrollerScrollAnimation release];
		}
	} else {
		[_transcriptView setFrame:endFrame];
		if( visible ) [_transcriptView scrollToBottomAnimated:NO];
	}

	if( animate ) {
		[[UIAnimator sharedAnimator] addAnimations:animations withDuration:0.25 start:YES];
		[animations release];
	} else if( ! visible ) {
		[_keyboard removeFromSuperview];
		[_keyboard release];
		_keyboard = nil;
	}
}
*/

#pragma mark -

- (void) textFieldDidBecomeFirstResponder:(id) textField {
//	[self setKeyboardVisible:YES animate:YES];
}

- (void) textFieldDidResignFirstResponder:(id) textField {
	if( _hiding || _reallyResignInputFirstResponder )
		return;
	[_inputField becomeFirstResponder];
	_reallyResignInputFirstResponder = NO;
}

#pragma mark -

- (void) styleViewDidAcceptFocusClick:(CQStyleView *) view {
	_reallyResignInputFirstResponder = YES;
	[_inputField resignFirstResponder];

//	[self setKeyboardVisible:NO animate:YES];
}

- (void) scrollerWillStartSmoothScrolling:(id) scroller {
	if( _keyboardVisible )
		[_inputField becomeFirstResponder];
}

#pragma mark -

/*
- (BOOL) keyboardInput:(UIFieldEditor *) editor shouldInsertText:(NSString *) text isMarkedText:(BOOL) marked {
	if( [text length] == 1 && [text characterAtIndex:0] == '\n' ) {
		[self send:editor];
		return NO;
	}

	return YES;
}

- (int) keyboardInput:(UIFieldEditor *) editor positionForAutocorrection:(id) autoCorrection {
	return 1; // position above the input field
}
*/

#pragma mark -

/*
- (BOOL) alwaysReturnsTypingAsPrimarySuggestion {
	return NO;
}

- (BOOL) shouldSuggestUserEnteredString:(NSString *) string {
	return NO;
}

- (NSArray *) suggestionsForString:(NSString *) string inputIndex:(unsigned) index {
	return nil;
}
*/

#pragma mark -

/*
- (UIView *) view {
	if( ! _view ) {
		CGRect screenRect = [[UIScreen mainScreen] applicationFrame];

		_view = [[UIView alloc] initWithFrame:CGRectMake(0., 45., screenRect.size.width, screenRect.size.height - 45.)];
		[_view setBackgroundColor:[UIColor whiteColor]];


		_inputBarView = [[CQInputBarView alloc] initWithFrame:CGRectMake(0., [_view frame].size.height - 40., [_view frame].size.width, 40.)];

		_inputField = [[CQChatInputField alloc] initWithFrame:CGRectMake(6., 8., screenRect.size.width - 8., 26.)];
		[_inputField setDelegate:self];
		[_inputField setEditingDelegate:self];
		[_inputField setTextSuggestionDelegate:self];
		[_inputField setFont:[UIFont fontWithName:@"Helvetica" size:16.]];
		[_inputField setPaddingTop:5.];
		[_inputField setPaddingLeft:10.];
		[_inputField setPaddingRight:10.];
		[_inputField setPaddingBottom:4.];
		[_inputBarView addSubview:_inputField];
		[_view addSubview:_transcriptView];
		[_view addSubview:_inputBarView];
	}

	return _view;
}
*/

- (UIImage *) icon {
	return [UIImage imageNamed:@"directChatIcon.png"];
}

- (void) setTitle:(NSString *) title {
	// Do nothing, not changeable.
}

- (NSString *) title {
	return [[self user] displayName];
}

- (MVChatConnection *) connection {
	return [[self user] connection];
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

}

- (void) viewDidAppear:(BOOL) animated {
	_unreadMessages = 0;
	_unreadHighlightedMessages = 0;
	_active = YES;
}

- (void) viewWillDisappear:(BOOL) animated {
	_active = NO;
	_hiding = YES;
	[_inputField resignFirstResponder];
}

- (void) viewDidDisappear:(BOOL) animated {
	_hiding = NO;
}

- (void) willClose {

}

#pragma mark -

- (void) send:(id) sender {
	NSString *message = [[_inputField text] retain];
	[_target sendMessage:message withEncoding:NSUTF8StringEncoding asAction:NO];
	[_inputField setText:@""];

	NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
	[self addMessageToDisplay:messageData fromUser:[(MVChatConnection *)[_target connection] localUser] asAction:NO withIdentifier:@"" andType:CQChatMessageNormalType];

	[message release];
}

#pragma mark -

- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier andType:(CQChatMessageType) type;
{
	[self addMessageToDisplay:message fromUser:user withAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:action] forKey:@"action"] withIdentifier:identifier andType:type];
}

- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user withAttributes:(NSDictionary *) msgAttributes withIdentifier:(NSString *) identifier andType:(CQChatMessageType) type {
/*
	DOMHTMLElement *body = [_transcriptView body];
	DOMDocument *document = [body ownerDocument];

	NSString *messageString = [[NSString alloc] initWithData:message encoding:NSUTF8StringEncoding];
	NSString *messagePreviewString = [NSString stringWithFormat:@"%@: %@", [user nickname], messageString];

	DOMHTMLElement *wrapperElement = (DOMHTMLElement *)[document createElement:@"div"];
	if( [[msgAttributes objectForKey:@"action"] boolValue] )
		[wrapperElement setAttribute:@"class" :@"message-wrapper action"];
	else [wrapperElement setAttribute:@"class" :@"message-wrapper"];

	DOMHTMLElement *senderElement = (DOMHTMLElement *)[document createElement:@"div"];
	if( [user isLocalUser] ) [senderElement setAttribute:@"class" :@"sender self"];
	else [senderElement setAttribute:@"class" :@"sender"];
	[senderElement setTextContent:[user nickname]];

	DOMHTMLElement *messageElement = (DOMHTMLElement *)[document createElement:@"div"];
	[messageElement setAttribute:@"class" :@"message"];
	[messageElement setTextContent:messageString];

	[CPURLifier urlIfyNode:messageElement];

	[messageString release];

	[wrapperElement appendChild:senderElement];
	[wrapperElement appendChild:messageElement];

	[body appendChild:wrapperElement];

	[_transcriptView scrollToBottom];

	if( ! [[_tableCell firstChatLineText] length] ) {
		[_tableCell setFirstChatLineText:messagePreviewString];
	} else if( ! [[_tableCell secondChatLineText] length] ) {
		[_tableCell setSecondChatLineText:messagePreviewString];
	} else {
		[_tableCell setFirstChatLineText:[_tableCell secondChatLineText]];
		[_tableCell setSecondChatLineText:messagePreviewString];
	}

	if( ! [user isLocalUser] ) {
		if( ! _active ) ++_unreadMessages;
		[[CQChatController defaultController] incrementApplicationBadgeByAmount:1];
	}
*/
}
@end
