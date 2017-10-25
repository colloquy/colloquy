#import "JVChatController.h"
#import "MVConnectionsController.h"
#import "JVChatWindowController.h"
#import "JVSidebarChatWindowController.h"
#import "JVTabbedChatWindowController.h"
#import "JVChatViewCriterionController.h"
#import "JVNotificationController.h"
#import "JVChatTranscriptPanel.h"
#import "JVSmartTranscriptPanel.h"
#import "JVDirectChatPanel.h"
#import "JVChatRoomPanel.h"
#import "JVChatConsolePanel.h"
#import "JVChatMessage.h"
#import "JVChatRoomMember.h"

#include <libxml/parser.h>

static JVChatController *sharedInstance = nil;
static NSMenu *smartTranscriptMenu = nil;

@interface JVChatController (JVChatControllerPrivate)
- (void) _joinedRoom:(NSNotification *) notification;
- (void) _invitedToRoom:(NSNotification *) notification;
- (void) _invitedToDirectChat:(NSNotification *) notification;
- (void) _gotBeep:(NSNotification *) notification;
- (void) _gotDirectChatMessage:(NSNotification *) notification;
- (void) _gotRoomMessage:(NSNotification *) notification;
- (void) _gotPrivateMessage:(NSNotification *) notification;
- (void) _errorOccurred:(NSNotification *) notification;
- (IBAction) _checkMemos:(id) sender;
- (IBAction) _newSmartTranscript:(id) sender;
- (void) _reloadPreferedWindowRuleSets;
@end

@implementation JVChatController
+ (JVChatController *) defaultController {
	if( ! sharedInstance ) {
		sharedInstance = [self alloc];
		sharedInstance = [sharedInstance init];
	}

	return sharedInstance;
}

+ (NSMenu *) smartTranscriptMenu {
	[self refreshSmartTranscriptMenu];
	return smartTranscriptMenu;
}

+ (void) refreshSmartTranscriptMenu {
	if( ! smartTranscriptMenu ) smartTranscriptMenu = [[NSMenu alloc] initWithTitle:@""];

	[smartTranscriptMenu removeAllItems];

	NSMenuItem *menuItem = nil;
	NSMutableArray *items = [NSMutableArray arrayWithArray:[[[self defaultController] smartTranscripts] allObjects]];
	[items sortUsingSelector:@selector( compare: )];

	for( JVSmartTranscriptPanel *panel in items ) {
		NSString *title = [panel title];
		if( [panel newMessagesWaiting] > 0 ) title = [NSString stringWithFormat:@"%@ (%ld)", [panel title], [panel newMessagesWaiting]];
		menuItem = [[NSMenuItem alloc] initWithTitle:title action:@selector( showView: ) keyEquivalent:@""];
		if( [panel newMessagesWaiting] ) [menuItem setImage:[NSImage imageNamed:@"smartTranscriptTabActivity"]];
		else {
			NSImage *icon = [NSImage imageNamed:@"smartTranscript"];
			icon.size = NSMakeSize(16, 16);
			[menuItem setImage:icon];
		}
		[menuItem setTarget:[self defaultController]];
		[menuItem setRepresentedObject:panel];
		[smartTranscriptMenu addItem:menuItem];
	}

	if( ! [items count] ) {
		menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"No Smart Transcripts", "no smart transcripts menu title" ) action:NULL keyEquivalent:@""];
		[smartTranscriptMenu addItem:menuItem];
	}

	[smartTranscriptMenu addItem:[NSMenuItem separatorItem]];

	menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"New Smart Transcript...", "new smart transcript menu title" ) action:@selector( _newSmartTranscript: ) keyEquivalent:@"n"];
	[menuItem setKeyEquivalentModifierMask:(NSCommandKeyMask | NSAlternateKeyMask)];
	[menuItem setTarget:[JVChatController defaultController]];
	[smartTranscriptMenu addItem:menuItem];
}

#pragma mark -

- (instancetype) init {
	if( ( self = [super init] ) ) {
		_chatWindows = [[NSMutableSet alloc] initWithCapacity:5];
		_chatControllers = [[NSMutableSet alloc] initWithCapacity:50];

		[self _reloadPreferedWindowRuleSets];

		for (NSData *archivedSmartTranscript in [[NSUserDefaults standardUserDefaults] objectForKey:@"JVSmartTranscripts"]) {
			id object = [NSKeyedUnarchiver unarchiveObjectWithData:archivedSmartTranscript];
			if( object ) [_chatControllers addObject:object];
		}

		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _joinedRoom: ) name:MVChatRoomJoinedNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _invitedToRoom: ) name:MVChatRoomInvitedNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _invitedToDirectChat: ) name:MVDirectChatConnectionOfferNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _gotBeep: ) name:MVChatConnectionGotBeepNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _gotPrivateMessage: ) name:MVChatConnectionGotPrivateMessageNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _gotRoomMessage: ) name:MVChatRoomGotMessageNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _gotDirectChatMessage: ) name:MVDirectChatConnectionGotMessageNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _errorOccurred: ) name:MVChatConnectionErrorNotification object:nil];
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter chatCenter] removeObserver:self];
	if( self == sharedInstance ) sharedInstance = nil;

}

#pragma mark -

- (void) addViewControllerToPreferedWindowController:(id <JVChatViewController>) controller userInitiated:(BOOL) initiated {
	JVChatWindowController *windowController = nil;

	BOOL finalMatch = NO;

	NSDictionary *windowSet = nil;
	for( windowSet in _windowRuleSets ) {
		for( NSDictionary *ruleSet in windowSet[@"rules"]) {
			BOOL andOperation = ( [ruleSet[@"operation"] intValue] == 2 );
			BOOL ignore = [ruleSet[@"ignoreCase"] boolValue];
			BOOL match = ( andOperation ? YES : NO );

			for( JVChatViewCriterionController *criterion in ruleSet[@"criterion"]) {
				BOOL localMatch = [criterion matchChatView:controller ignoringCase:ignore];
				match = ( andOperation ? ( match & localMatch ) : ( match | localMatch ) );
				if( ! localMatch && andOperation ) break; // fails, this wont match with all rules
				else if( localMatch && ! andOperation ) break; // passes one, this is enough to match under "any rules"
			}

			if( match ) {
				finalMatch = YES;
				break;
			}
		}

		if( finalMatch ) break;
	}

	if( finalMatch && windowSet ) {
		if( [windowSet[@"special"] isEqualToString:@"currentWindow"] || [windowSet[@"currentWindow"] boolValue] ) {
			for( windowController in _chatWindows )
				if( [[windowController window] isMainWindow] ) break;
			if( ! windowController ) windowController = [_chatWindows anyObject];
		} else if( [windowSet[@"special"] isEqualToString:@"newWindow"] ) {
			windowController = [self createChatWindowController];
		} else if( [windowSet[@"special"] isEqualToString:@"serverWindow"] ) {
			windowController = [self chatWindowControllerWithIdentifier:[[controller connection] server]];
		} else if( [(NSString *)windowSet[@"identifier"] length] ) {
			windowController = [self chatWindowControllerWithIdentifier:windowSet[@"identifier"]];
		}
	}

	if( ! windowController ) windowController = [self createChatWindowController];

	if( [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSCommandKeyMask ) initiated = NO;
	if( [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSShiftKeyMask ) initiated = NO;

	[windowController addChatViewController:controller];

	if( initiated || [[windowController allChatViewControllers] count] == 1 )
		[windowController showChatViewController:controller];

	if( initiated ) [windowController showWindow:nil];
}

#pragma mark -

- (NSSet *) allChatWindowControllers {
	return [NSSet setWithSet:_chatWindows];
}

- (JVChatWindowController *) createChatWindowController {
	JVChatWindowController *windowController = nil;
	if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatWindowInterface"] == 1 )
		windowController = [[JVTabbedChatWindowController alloc] init];
	else windowController = [[JVSidebarChatWindowController alloc] init];
	if( windowController )
		[_chatWindows addObject:windowController];
	return windowController;
}

- (JVChatWindowController *) chatWindowControllerWithIdentifier:(NSString *) identifier {
	JVChatWindowController *windowController = nil;

	for( windowController in _chatWindows )
		if( [[windowController identifier] isEqualToString:identifier] )
			break;

	if( ! windowController ) {
		windowController = [self createChatWindowController];
		[windowController setIdentifier:identifier];
	}

	return windowController;
}

- (void) disposeChatWindowController:(JVChatWindowController *) controller {
	NSParameterAssert( controller != nil );

	for( id view in [controller allChatViewControllers] )
		[self disposeViewController:view];

	[_chatWindows removeObject:controller];
}

#pragma mark -

- (NSSet *) allChatViewControllers {
	return [NSSet setWithSet:_chatControllers];
}

- (NSSet *) chatViewControllersWithConnection:(MVChatConnection *) connection {
	NSParameterAssert( connection != nil );

	NSMutableSet *ret = [NSMutableSet set];
	for( id <JVChatViewController> item in _chatControllers )
		if( [item connection] == connection )
			[ret addObject:item];

	return ret;
}

- (NSSet *) chatViewControllersOfClass:(Class) class {
	NSParameterAssert( class != nil );
	
	NSMutableSet *ret = [NSMutableSet set];
	for( id <JVChatViewController> item in _chatControllers )
		if( [item isMemberOfClass:class] )
			[ret addObject:item];
	
	return ret;
}

- (NSSet *) chatViewControllersKindOfClass:(Class) class {
	NSParameterAssert( class != nil );
	
	NSMutableSet *ret = [NSMutableSet set];
	for( id <JVChatViewController> item in _chatControllers )
		if( [item isKindOfClass:class] )
			[ret addObject:item];
	
	return ret;
}

#pragma mark -

- (JVChatRoomPanel *) chatViewControllerForRoom:(MVChatRoom *) room ifExists:(BOOL) exists {
	NSParameterAssert( room != nil );

	id ret = nil;

	for( ret in _chatControllers )
		if( [ret isMemberOfClass:[JVChatRoomPanel class]] && [[ret target] isEqual:room] )
			break;

	if( ! ret && ! exists ) {
		if( ( ret = [[JVChatRoomPanel alloc] initWithTarget:room] ) ) {
			[_chatControllers addObject:ret];
			[self addViewControllerToPreferedWindowController:ret userInitiated:YES];
		}
	}

	return ret;
}

- (JVDirectChatPanel *) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists {
	return [self chatViewControllerForUser:user ifExists:exists userInitiated:YES];
}

- (JVDirectChatPanel *) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists userInitiated:(BOOL) initiated {
	NSParameterAssert( user != nil );

	id ret = nil;

	for( ret in _chatControllers )
		if( [ret isMemberOfClass:[JVDirectChatPanel class]] && [[ret target] isEqual:user] )
			break;

	if( ! ret && ! exists ) {
		if( ( ret = [[JVDirectChatPanel alloc] initWithTarget:user] ) ) {
			[_chatControllers addObject:ret];
			[self addViewControllerToPreferedWindowController:ret userInitiated:initiated];
		}
	}

	return ret;
}

- (JVDirectChatPanel *) chatViewControllerForDirectChatConnection:(MVDirectChatConnection *) connection ifExists:(BOOL) exists {
	return [self chatViewControllerForDirectChatConnection:connection ifExists:exists userInitiated:YES];
}

- (JVDirectChatPanel *) chatViewControllerForDirectChatConnection:(MVDirectChatConnection *) connection ifExists:(BOOL) exists userInitiated:(BOOL) initiated {
	NSParameterAssert( connection != nil );

	id ret = nil;

	for( ret in _chatControllers )
		if( [ret isMemberOfClass:[JVDirectChatPanel class]] && [[ret target] isEqual:connection] )
			break;

	if( ! ret && ! exists ) {
		if( ( ret = [[JVDirectChatPanel alloc] initWithTarget:connection] ) ) {
			[_chatControllers addObject:ret];
			[self addViewControllerToPreferedWindowController:ret userInitiated:initiated];
		}
	}

	return ret;
}

- (JVChatTranscriptPanel *) chatViewControllerForTranscript:(NSString *) filename {
	id ret = nil;
	if( ( ret = [[JVChatTranscriptPanel alloc] initWithTranscript:filename] ) ) {
		[_chatControllers addObject:ret];
		[self addViewControllerToPreferedWindowController:ret userInitiated:YES];
	}

	return ret;
}

#pragma mark -

- (JVSmartTranscriptPanel *) createSmartTranscript {
	JVSmartTranscriptPanel *ret = nil;
	if( ( ret = [[JVSmartTranscriptPanel alloc] initWithSettings:nil] ) ) {
		[_chatControllers addObject:ret];
		[self addViewControllerToPreferedWindowController:ret userInitiated:YES];
		[ret editSettings:nil];
	}

	return ret;
}

- (NSSet *) smartTranscripts {
	return [self chatViewControllersOfClass:[JVSmartTranscriptPanel class]];
}

- (void) saveSmartTranscripts {
	NSMutableArray *smartTranscripts = [NSMutableArray array];

	for( JVSmartTranscriptPanel *smartTranscript in [self smartTranscripts] ) {
		NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:smartTranscript];
		if( archived ) [smartTranscripts addObject:archived];
	}

	[[self class] refreshSmartTranscriptMenu];
	[[NSUserDefaults standardUserDefaults] setObject:smartTranscripts forKey:@"JVSmartTranscripts"];
}

- (void) disposeSmartTranscript:(JVSmartTranscriptPanel *) panel {
	NSParameterAssert( panel != nil );

	if( [panel respondsToSelector:@selector( willDispose )] )
		[(id<JVChatViewController>)panel willDispose];

	[[panel windowController] removeChatViewController:panel];
	[_chatControllers removeObject:panel];

	[self saveSmartTranscripts];
}

#pragma mark -

- (JVChatConsolePanel *) chatConsoleForConnection:(MVChatConnection *) connection ifExists:(BOOL) exists {
	NSParameterAssert( connection != nil );

	id <JVChatViewController> ret = nil;

	for( ret in _chatControllers )
		if( [ret isMemberOfClass:[JVChatConsolePanel class]] && [ret connection] == connection )
			break;

	if( ! ret && ! exists ) {
		if( ( ret = [[JVChatConsolePanel alloc] initWithConnection:connection] ) ) {
			[_chatControllers addObject:ret];
			[self addViewControllerToPreferedWindowController:ret userInitiated:YES];
		}
	}

	return (JVChatConsolePanel *)ret;
}

#pragma mark -

- (void) disposeViewController:(id <JVChatViewController>) controller {
	NSParameterAssert( controller != nil );

	if( [controller respondsToSelector:@selector( willDispose )] )
		[(id<JVChatViewController>)controller willDispose];

	[[controller windowController] removeChatViewController:controller];

	if( [controller isKindOfClass:[JVSmartTranscriptPanel class]] ) return;

	[_chatControllers removeObject:controller];
}

- (void) detachViewController:(id <JVChatViewController>) controller {
	NSParameterAssert( controller != nil );


	JVChatWindowController *windowController = [self createChatWindowController];
	[[controller windowController] removeChatViewController:controller];

	[[windowController window] setFrameUsingName:[NSString stringWithFormat:@"Chat Window %@", [controller identifier]]];

	NSRect frame = [[windowController window] frame];
	NSPoint point = [[windowController window] cascadeTopLeftFromPoint:NSMakePoint( NSMinX( frame ), NSMaxY( frame ) )];
	[[windowController window] setFrameTopLeftPoint:point];

	[[windowController window] saveFrameUsingName:[NSString stringWithFormat:@"Chat Window %@", [controller identifier]]];

	[windowController addChatViewController:controller];

}

#pragma mark -

- (IBAction) showView:(id) sender {
	id <JVChatViewController> view = [sender representedObject];
	if( ! view ) return;
	if( [view windowController] ) [[view windowController] showChatViewController:view];
	else [self addViewControllerToPreferedWindowController:view userInitiated:YES];
}

- (IBAction) detachView:(id) sender {
	id <JVChatViewController> view = [sender representedObject];
	if( ! view ) return;
	[self detachViewController:view];
}

#pragma mark -
#pragma mark Ignores

- (JVIgnoreMatchResult) shouldIgnoreUser:(MVChatUser *) user withMessage:(NSAttributedString *) message inView:(id <JVChatViewController>) view {
	JVIgnoreMatchResult ignoreResult = JVNotIgnored;
	NSEnumerator *renum = [[[MVConnectionsController defaultController] ignoreRulesForConnection:[user connection]] objectEnumerator];
	KAIgnoreRule *rule = nil;

	while( ( ignoreResult == JVNotIgnored ) && ( ( rule = [renum nextObject] ) ) ) {
		ignoreResult = [rule matchUser:user message:[message string] inView:view];
	}

	return ignoreResult;
}
@end

#pragma mark -

@implementation JVChatController (JVChatControllerPrivate)
- (void) _joinedRoom:(NSNotification *) notification {
	MVChatRoom *rm = [notification object];
	if( ! [[MVConnectionsController defaultController] managesConnection:[rm connection]] ) return;
	JVChatRoomPanel *room = [self chatViewControllerForRoom:rm ifExists:NO];
	[room joined];
}

- (void) _invitedToRoom:(NSNotification *) notification {
	NSString *room = [notification userInfo][@"room"];
	MVChatUser *user = [notification userInfo][@"user"];
	MVChatConnection *connection = [notification object];

	if( ! [[MVConnectionsController defaultController] managesConnection:connection] ) return;

	MVChatUser *invitedUser = notification.userInfo[@"target"];
	if (invitedUser) {
		NSString *message = [NSString stringWithFormat:NSLocalizedString(@"%@ invited %@ to \"%@\" on \"%@\".", "User invited to join room alert message"), user.displayName, invitedUser.displayName,  room, connection.server];
		MVChatRoom *roomInstance = [connection chatRoomWithName:room];
		JVChatRoomPanel *chatRoomPanel = [self chatViewControllerForRoom:roomInstance ifExists:NO];
		[chatRoomPanel addEventMessageToDisplay:message withName:@"invite" andAttributes:nil];
		return;
	}


	NSMutableDictionary *context = [NSMutableDictionary dictionary];
	context[@"title"] = NSLocalizedString( @"Invited to Chat", "bubble title invited to room" );
	context[@"description"] = [NSString stringWithFormat:NSLocalizedString( @"You were invited to %@ by %@.", "bubble message invited to room" ), room, [user nickname]];
	[[JVNotificationController defaultController] performNotification:@"JVChatRoomInvite" withContextInfo:context];
	
	BOOL(^presentInvitationAlert)(NSString *, MVChatUser *) = ^BOOL(NSString *roomToJoin, MVChatUser *invitingUser) {
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = NSLocalizedString( @"Chat Room Invite", "member invited to room title" );
		alert.informativeText = [NSString stringWithFormat:NSLocalizedString( @"You were invited to join %@ by %@. Would you like to accept this invitation and join this room?", "you were invited to join a chat room status message" ), roomToJoin, [invitingUser nickname]];
		alert.alertStyle = NSAlertStyleInformational;
		[alert addButtonWithTitle:NSLocalizedString( @"Join", "join button" )];
		[alert addButtonWithTitle:NSLocalizedString( @"Decline", "decline button" )];
		NSModalResponse response = [alert runModal];
		return response == NSAlertFirstButtonReturn;
	};

	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVAutoJoinChatRoomOnInvite"] || presentInvitationAlert(room, user) ) {
		[connection joinChatRoomNamed:room];
	}
}

- (void) _invitedToDirectChat:(NSNotification *) notification {
	MVChatUser *user = [notification userInfo][@"user"];
	MVDirectChatConnection *connection = [notification object];

	if( ! [[MVConnectionsController defaultController] managesConnection:[user connection]] ) return;

	NSString *title = NSLocalizedString( @"Direct Chat Invite", "invited to direct chat title" );
	NSString *message = [NSString stringWithFormat:NSLocalizedString( @"You were invited to participate in a chat with %@. Would you like to accept this invitation?", "you were invited to a direct chat status message" ), [user nickname]];

	NSMutableDictionary *context = [NSMutableDictionary dictionary];
	context[@"title"] = NSLocalizedString( @"Invited to Direct Chat", "bubble title invited to direct chat" );
	context[@"description"] = [NSString stringWithFormat:NSLocalizedString( @"You were invited to participate in a chat with %@.", "bubble message invited to participate in a direct chat" ), [user nickname]];
	[[JVNotificationController defaultController] performNotification:@"JVDirectChatInvite" withContextInfo:context];

	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = title;
	alert.informativeText = message;
	alert.alertStyle = NSAlertStyleInformational;
	[alert addButtonWithTitle:NSLocalizedString( @"Accept", "accept button" )];
	[alert addButtonWithTitle:NSLocalizedString( @"Decline", "decline button" )];
	NSModalResponse response = [alert runModal];
	
	if( response == NSAlertFirstButtonReturn ) {
		[self chatViewControllerForDirectChatConnection:connection ifExists:NO userInitiated:NO];
		[connection initiate];
	}
}

- (void) _gotBeep:(NSNotification *) notification {
	NSDictionary *userInfo = [notification userInfo];
	MVChatUser *user = userInfo[@"user"];

	NSMutableDictionary *context = [NSMutableDictionary dictionary];
	context[@"title"] = NSLocalizedString( @"Beep received", "beep bubble title" );
	context[@"description"] = [NSString stringWithFormat:NSLocalizedString( @"%@ is reclaiming your attention by means of a beep.", "beep bubble text" ), [user nickname]];
	context[@"image"] = [NSImage imageNamed:@"activityNewImportant"];
	context[@"coalesceKey"] = [[user nickname] stringByAppendingString:@"JVChatBeeped"];
	context[@"target"] = self;
	context[@"action"] = NSStringFromSelector( @selector( activate: ) );
	[[JVNotificationController defaultController] performNotification:@"JVChatBeeped" withContextInfo:context];
}

- (void) _gotDirectChatMessage:(NSNotification *) notification {
	MVDirectChatConnection *connection = [notification object];
	NSData *message = [notification userInfo][@"message"];
	MVChatUser *user = [connection user];

	if( ! [[MVConnectionsController defaultController] managesConnection:[user connection]] ) return;

	if( ( [self shouldIgnoreUser:user withMessage:nil inView:nil] == JVNotIgnored ) ) {
		JVDirectChatPanel *controller = [self chatViewControllerForDirectChatConnection:connection ifExists:NO userInitiated:NO];
		[controller addMessageToDisplay:message fromUser:user withAttributes:[notification userInfo] withIdentifier:[notification userInfo][@"identifier"] andType:JVChatMessageNormalType];
	}
}

- (void) _gotRoomMessage:(NSNotification *) notification {
	// we do this here to make sure we catch early messages right when we join (this includes dircproxy's dump)
	MVChatRoom *room = [notification object];
	JVChatRoomPanel *controller = [self chatViewControllerForRoom:room ifExists:NO];
	[controller handleRoomMessageNotification:notification];
}

- (void) _gotPrivateMessage:(NSNotification *) notification {
	MVChatUser *user = [notification object];

	if( ! [[MVConnectionsController defaultController] managesConnection:[user connection]] ) return;

	NSData *message = [notification userInfo][@"message"];
	MVChatUser* sender = user;

	if( [user isLocalUser] && [notification userInfo][@"target"] )
		user = [notification userInfo][@"target"];

	BOOL hideFromUser = NO;
	if( [[notification userInfo][@"notice"] boolValue] ) {

		if( ! [self chatViewControllerForUser:user ifExists:YES] && ( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatAlwaysShowNotices"] == 0 || ( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatAlwaysShowNotices"] == 2 && [notification userInfo][@"handled"] ) ) )
			hideFromUser = YES;

		MVChatConnection *connection = [user connection];
		NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObjectsAndKeys:@([connection encoding]), @"StringEncoding", @([[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageColors"]), @"IgnoreFontColors", @([[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageFormatting"]), @"IgnoreFontTraits", [NSFont systemFontOfSize:11.], @"BaseFont", nil];
		NSAttributedString *messageString = [NSAttributedString attributedStringWithChatFormat:message options:options];
		if( ! messageString ) {
			options[@"StringEncoding"] = @(NSISOLatin1StringEncoding);
			messageString = [NSAttributedString attributedStringWithChatFormat:message options:options];
		}

		if( [[user nickname] isEqualToString:@"MemoServ"] && [[messageString string] rangeOfString:@"new memo" options:NSCaseInsensitiveSearch].location != NSNotFound && [[messageString string] rangeOfString:@" no " options:NSCaseInsensitiveSearch].location == NSNotFound ) {

			NSMutableDictionary *context = [NSMutableDictionary dictionary];
			context[@"title"] = NSLocalizedString( @"You Have New Memos", "new memos bubble title" );
			context[@"description"] = messageString;
			context[@"image"] = [NSImage imageNamed:@"Stickies"];
			context[@"target"] = self;
			context[@"action"] = NSStringFromSelector( @selector( _checkMemos: ) );
			context[@"representedObject"] = connection;
			[[JVNotificationController defaultController] performNotification:@"JVNewMemosFromServer" withContextInfo:context];

		} else {
			NSMutableDictionary *context = [[NSMutableDictionary alloc] init];
			context[@"title"] = [NSString stringWithFormat:NSLocalizedString( @"Notice from %@", "notice message from user title" ), [user displayName]];
			context[@"description"] = messageString;
			context[@"image"] = [NSImage imageNamed:@"activityNewImportant"];
			NSString *type = ( hideFromUser ? @"JVChatUnhandledNoticeMessage" : @"JVChatNoticeMessage" );
			[[JVNotificationController defaultController] performNotification:type withContextInfo:context];
		}
	}

	if( ! hideFromUser && ( [self shouldIgnoreUser:user withMessage:nil inView:nil] == JVNotIgnored ) ) {
		JVDirectChatPanel *controller = [self chatViewControllerForUser:user ifExists:NO userInitiated:NO];
		JVChatMessageType type = ( [[notification userInfo][@"notice"] boolValue] ? JVChatMessageNoticeType : JVChatMessageNormalType );
		[controller addMessageToDisplay:message fromUser:sender withAttributes:[notification userInfo] withIdentifier:[notification userInfo][@"identifier"] andType:type];
	}
}

- (void) _errorOccurred:(NSNotification *) notification {
	NSError *error = [notification userInfo][@"error"];
	if( [error code] == MVChatConnectionErroneusNicknameError ) {
		NSString *nickname = [error userInfo][@"nickname"];
		NSAlert *alert = [[NSAlert alloc] init];
		[alert setMessageText:NSLocalizedString( @"Connection error", "connection error alert dialog title" )];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString( @"Could not connect to server because the requested nickname (%@) was unavailable or invalid.", "connection error alert dialog message" ), nickname]];
		[alert setAlertStyle:NSInformationalAlertStyle];
		[alert runModal];
	} else if( [error code] == MVChatConnectionNoSuchUserError ) {
		MVChatUser *user = [error userInfo][@"user"];
		JVDirectChatPanel *panel = [self chatViewControllerForUser:user ifExists:YES];
		if( ! panel || ( panel && [[panel windowController] activeChatViewController] != panel ) ) {
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText:[NSString stringWithFormat:NSLocalizedString( @"User \"%@\" is not online", "user not online alert dialog title" ), [user displayName]]];
			[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString( @"The user \"%@\" is not online and is unavailable until they reconnect.", "user not online alert dialog message" ), [user displayName]]];
			[alert setAlertStyle:NSInformationalAlertStyle];
			[alert runModal];
		}
	} else if( [error code] == MVChatConnectionOutOfBricksError ) {
		NSAlert *alert = [[NSAlert alloc] init];
		[alert setMessageText:NSLocalizedString( @"Out of bricks", "out of bricks alert dialog title" )];
		[alert setInformativeText:NSLocalizedString( @"The user you specified could not be bricked because you are out of bricks. You can regain some more when somebody else bricks you.", "out of bricks alert dialog message" )];
		[alert setAlertStyle:NSInformationalAlertStyle];
		[alert runModal];
	} else if( [error code] == MVChatConnectionProtocolError ) {
		NSString *reason = [error userInfo][@"reason"];
		NSAlert *alert = [[NSAlert alloc] init];
		[alert setMessageText:NSLocalizedString( @"Chat protocol error", "malformed packet alert dialog title" )];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString( @"Client got a malformed packet: %@", "malformed packet alert dialog message" ), reason]];
		[alert setAlertStyle:NSInformationalAlertStyle];
		[alert runModal];
	}
}

- (IBAction) _checkMemos:(id) sender {
	MVChatConnection *connection = [sender representedObject];
	NSAttributedString *message = [[NSAttributedString alloc] initWithString:@"read all"];
	MVChatUser *user = [connection chatUserWithUniqueIdentifier:@"MemoServ"];
	[user sendMessage:message withEncoding:[connection encoding] asAction:NO];
	[self chatViewControllerForUser:user ifExists:NO];
}

- (IBAction) _newSmartTranscript:(id) sender {
	[[JVChatController defaultController] createSmartTranscript];
}

- (void) _reloadPreferedWindowRuleSets {
	NSData *data = [[NSUserDefaults standardUserDefaults] dataForKey:@"JVChatWindowRuleSets"];
	_windowRuleSets = ( [data length] ? [NSKeyedUnarchiver unarchiveObjectWithData:data] : nil );
}
@end

#pragma mark -

@implementation JVChatTranscriptPanel (JVChatTranscriptObjectSpecifier)
- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[NSApplication class]];
	NSScriptObjectSpecifier *container = [[NSApplication sharedApplication] objectSpecifier];
	return [[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"chatTranscripts" uniqueID:[self uniqueIdentifier]];
}
@end

#pragma mark -

@implementation JVSmartTranscriptPanel (JVSmartTranscriptPanelObjectSpecifier)
- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[NSApplication class]];
	NSScriptObjectSpecifier *container = [[NSApplication sharedApplication] objectSpecifier];
	return [[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"smartTranscripts" uniqueID:[self uniqueIdentifier]];
}
@end

#pragma mark -

@implementation JVDirectChatPanel (JVDirectChatPanelObjectSpecifier)
- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[NSApplication class]];
	NSScriptObjectSpecifier *container = [[NSApplication sharedApplication] objectSpecifier];
	return [[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"directChats" uniqueID:[self uniqueIdentifier]];
}
@end

#pragma mark -

@implementation JVChatRoomPanel (JVChatRoomPanelObjectSpecifier)
- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[NSApplication class]];
	NSScriptObjectSpecifier *container = [[NSApplication sharedApplication] objectSpecifier];
	return [[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"chatRooms" uniqueID:[self uniqueIdentifier]];
}
@end

#pragma mark -

@implementation JVChatConsolePanel (JVChatConsolePanelObjectSpecifier)
- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[NSApplication class]];
	NSScriptObjectSpecifier *container = [[NSApplication sharedApplication] objectSpecifier];
	return [[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"chatConsoles" uniqueID:[self uniqueIdentifier]];
}
@end

#pragma mark -

@interface JVStartChatScriptCommand : NSScriptCommand {}
@end

#pragma mark -

@implementation JVStartChatScriptCommand
- (id) performDefaultImplementation {
	NSDictionary *args = [self evaluatedArguments];
	id target = args[@"target"];

	if( target && [target isKindOfClass:[NSString class]] ) {
		MVChatConnection *connection = args[@"connection"];
		if( ! connection ) {
			[self setScriptErrorNumber:1000];
			[self setScriptErrorString:@"The connection parameter was missing and is required when the user is a nickname string."];
			return nil;
		}

		if( ! [connection isConnected] ) {
			[self setScriptErrorNumber:1000];
			[self setScriptErrorString:@"The connection needs to be connected before you can find a chat user by their nickname."];
			return nil;
		}

		NSString *nickname = target;
		target = [[connection chatUsersWithNickname:nickname] anyObject];

		if( ! target ) {
			[self setScriptErrorNumber:1000];
			[self setScriptErrorString:[NSString stringWithFormat:@"The connection did not find a chat user with the nickname \"%@\".", nickname]];
			return nil;
		}
	}

	if( ! target || ( ! [target isKindOfClass:[MVChatUser class]] && ! [target isKindOfClass:[JVChatRoomMember class]] ) ) {
		[self setScriptErrorNumber:1000];
		[self setScriptErrorString:@"The \"for\" parameter was missing or not a chat user or member object."];
		return nil;
	}

	if( [target isKindOfClass:[MVChatUser class]] && [(MVChatUser *)target type] == MVChatWildcardUserType ) {
		[self setScriptErrorNumber:1000];
		[self setScriptErrorString:@"The \"for\" parameter cannot be a wildcard user."];
		return nil;
	}

	if( [target isKindOfClass:[JVChatRoomMember class]] )
		target = [(JVChatRoomMember *)target user];

	JVDirectChatPanel *panel = [[JVChatController defaultController] chatViewControllerForUser:target ifExists:NO];
	[[panel windowController] showChatViewController:panel];

	return panel;
}
@end

#pragma mark -

@implementation NSApplication (JVChatControllerScripting)
- (void) scriptErrorChantAddToChatViews {
	[[NSScriptCommand currentCommand] setScriptErrorString:@"Can't add, insert or replace a panel at the application level."];
	[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
}

#pragma mark -

- (NSArray *) chatViews {
	return [[[JVChatController defaultController] allChatViewControllers] allObjects];
}

- (id <JVChatViewController>) valueInChatViewsAtIndex:(NSUInteger) index {
	return [self chatViews][index];
}

- (id <JVChatViewController>) valueInChatViewsWithUniqueID:(id) identifier {
	for( id <JVChatViewController, JVChatListItemScripting> view in [[JVChatController defaultController] allChatViewControllers] ) 
		if( [view conformsToProtocol:@protocol( JVChatListItemScripting )] &&
			[[view uniqueIdentifier] isEqual:identifier] ) return view;

	return nil;
}

- (id <JVChatViewController>) valueInChatViewsWithName:(NSString *) name {
	for( id <JVChatViewController> view in [[JVChatController defaultController] allChatViewControllers] )
		if( [[view title] isEqualToString:name] )
			return view;

	return nil;
}

- (void) addInChatViews:(id <JVChatViewController>) view {
	[self scriptErrorChantAddToChatViews];
}

- (void) insertInChatViews:(id <JVChatViewController>) view {
	[self scriptErrorChantAddToChatViews];
}

- (void) insertInChatViews:(id <JVChatViewController>) view atIndex:(NSUInteger) index {
	[self scriptErrorChantAddToChatViews];
}

- (void) removeFromChatViewsAtIndex:(NSUInteger) index {
	id <JVChatViewController> view = [self chatViews][index];
	if( view ) [[JVChatController defaultController] disposeViewController:view];
}

- (void) replaceInChatViews:(id <JVChatViewController>) view atIndex:(NSUInteger) index {
	[self scriptErrorChantAddToChatViews];
}

#pragma mark -

- (NSArray *) chatViewsWithClass:(Class) class {
	return [[[JVChatController defaultController] chatViewControllersOfClass:class] allObjects];
}

- (id <JVChatViewController>) valueInChatViewsAtIndex:(NSUInteger) index withClass:(Class) class {
	return [self chatViewsWithClass:class][index];
}

- (id <JVChatViewController>) valueInChatViewsWithUniqueID:(id) identifier andClass:(Class) class {
	return [self valueInChatViewsWithUniqueID:identifier];
}

- (id <JVChatViewController>) valueInChatViewsWithName:(NSString *) name andClass:(Class) class {
	for( id <JVChatViewController> view  in [self chatViewsWithClass:class] )
		if( [[view title] isEqualToString:name] )
			return view;

	return nil;
}

- (void) removeFromChatViewsAtIndex:(NSUInteger) index withClass:(Class) class {
	id <JVChatViewController> view = [self chatViewsWithClass:class][index];
	if( view ) [[JVChatController defaultController] disposeViewController:view];
}

#pragma mark -

- (NSArray *) chatRooms {
	return [self chatViewsWithClass:[JVChatRoomPanel class]];
}

- (id <JVChatViewController>) valueInChatRoomsAtIndex:(NSUInteger) index {
	return [self valueInChatViewsAtIndex:index withClass:[JVChatRoomPanel class]];
}

- (id <JVChatViewController>) valueInChatRoomsWithUniqueID:(id) identifier {
	return [self valueInChatViewsWithUniqueID:identifier andClass:[JVChatRoomPanel class]];
}

- (id <JVChatViewController>) valueInChatRoomsWithName:(NSString *) name {
	return [self valueInChatViewsWithName:name andClass:[JVChatRoomPanel class]];
}

- (void) addInChatRooms:(id <JVChatViewController>) view {
	[self scriptErrorChantAddToChatViews];
}

- (void) insertInChatRooms:(id <JVChatViewController>) view {
	[self scriptErrorChantAddToChatViews];
}

- (void) insertInChatRooms:(id <JVChatViewController>) view atIndex:(NSUInteger) index {
	[self scriptErrorChantAddToChatViews];
}

- (void) removeFromChatRoomsAtIndex:(NSUInteger) index {
	[self removeFromChatViewsAtIndex:index withClass:[JVChatRoomPanel class]];
}

- (void) replaceInChatRooms:(id <JVChatViewController>) view atIndex:(NSUInteger) index {
	[self scriptErrorChantAddToChatViews];
}

#pragma mark -

- (NSArray *) directChats {
	return [self chatViewsWithClass:[JVDirectChatPanel class]];
}

- (id <JVChatViewController>) valueInDirectChatsAtIndex:(NSUInteger) index {
	return [self valueInChatViewsAtIndex:index withClass:[JVDirectChatPanel class]];
}

- (id <JVChatViewController>) valueInDirectChatsWithUniqueID:(id) identifier {
	return [self valueInChatViewsWithUniqueID:identifier andClass:[JVDirectChatPanel class]];
}

- (id <JVChatViewController>) valueInDirectChatsWithName:(NSString *) name {
	return [self valueInChatViewsWithName:name andClass:[JVDirectChatPanel class]];
}

- (void) addInDirectChats:(id <JVChatViewController>) view {
	[self scriptErrorChantAddToChatViews];
}

- (void) insertInDirectChats:(id <JVChatViewController>) view {
	[self scriptErrorChantAddToChatViews];
}

- (void) insertInDirectChats:(id <JVChatViewController>) view atIndex:(NSUInteger) index {
	[self scriptErrorChantAddToChatViews];
}

- (void) removeFromDirectChatsAtIndex:(NSUInteger) index {
	[self removeFromChatViewsAtIndex:index withClass:[JVDirectChatPanel class]];
}

- (void) replaceInDirectChats:(id <JVChatViewController>) view atIndex:(NSUInteger) index {
	[self scriptErrorChantAddToChatViews];
}

#pragma mark -

- (NSArray *) chatTranscripts {
	return [self chatViewsWithClass:[JVChatTranscriptPanel class]];
}

- (id <JVChatViewController>) valueInChatTranscriptsAtIndex:(NSUInteger) index {
	return [self valueInChatViewsAtIndex:index withClass:[JVChatTranscriptPanel class]];
}

- (id <JVChatViewController>) valueInChatTranscriptsWithUniqueID:(id) identifier {
	return [self valueInChatViewsWithUniqueID:identifier andClass:[JVChatTranscriptPanel class]];
}

- (id <JVChatViewController>) valueInChatTranscriptsWithName:(NSString *) name {
	return [self valueInChatViewsWithName:name andClass:[JVChatTranscriptPanel class]];
}

- (void) addInChatTranscripts:(id <JVChatViewController>) view {
	[self scriptErrorChantAddToChatViews];
}

- (void) insertInChatTranscripts:(id <JVChatViewController>) view {
	[self scriptErrorChantAddToChatViews];
}

- (void) insertInChatTranscripts:(id <JVChatViewController>) view atIndex:(NSUInteger) index {
	[self scriptErrorChantAddToChatViews];
}

- (void) removeFromChatTranscriptsAtIndex:(NSUInteger) index {
	[self removeFromChatViewsAtIndex:index withClass:[JVChatTranscriptPanel class]];
}

- (void) replaceInChatTranscripts:(id <JVChatViewController>) view atIndex:(NSUInteger) index {
	[self scriptErrorChantAddToChatViews];
}


#pragma mark -

- (NSArray *) smartTranscripts {
	return [self chatViewsWithClass:[JVSmartTranscriptPanel class]];
}

- (id <JVChatViewController>) valueInSmartTranscriptsAtIndex:(NSUInteger) index {
	return [self valueInChatViewsAtIndex:index withClass:[JVSmartTranscriptPanel class]];
}

- (id <JVChatViewController>) valueInSmartTranscriptsWithUniqueID:(id) identifier {
	return [self valueInChatViewsWithUniqueID:identifier andClass:[JVSmartTranscriptPanel class]];
}

- (id <JVChatViewController>) valueInSmartTranscriptsWithName:(NSString *) name {
	return [self valueInChatViewsWithName:name andClass:[JVSmartTranscriptPanel class]];
}

- (void) addInSmartTranscripts:(id <JVChatViewController>) view {
	[self scriptErrorChantAddToChatViews];
}

- (void) insertInSmartTranscripts:(id <JVChatViewController>) view {
	[self scriptErrorChantAddToChatViews];
}

- (void) insertInSmartTranscripts:(id <JVChatViewController>) view atIndex:(NSUInteger) index {
	[self scriptErrorChantAddToChatViews];
}

- (void) removeFromSmartTranscriptsAtIndex:(NSUInteger) index {
	[self removeFromChatViewsAtIndex:index withClass:[JVSmartTranscriptPanel class]];
}

- (void) replaceInSmartTranscripts:(id <JVChatViewController>) view atIndex:(NSUInteger) index {
	[self scriptErrorChantAddToChatViews];
}

#pragma mark -

- (NSArray *) chatConsoles {
	return [self chatViewsWithClass:[JVChatConsolePanel class]];
}

- (id <JVChatViewController>) valueInChatConsolesAtIndex:(NSUInteger) index {
	return [self valueInChatViewsAtIndex:index withClass:[JVChatConsolePanel class]];
}

- (id <JVChatViewController>) valueInChatConsolesWithUniqueID:(id) identifier {
	return [self valueInChatViewsWithUniqueID:identifier andClass:[JVChatConsolePanel class]];
}

- (id <JVChatViewController>) valueInChatConsolesWithName:(NSString *) name {
	return [self valueInChatViewsWithName:name andClass:[JVChatConsolePanel class]];
}

- (void) addInChatConsoles:(id <JVChatViewController>) view {
	[self scriptErrorChantAddToChatViews];
}

- (void) insertInChatConsoles:(id <JVChatViewController>) view {
	[self scriptErrorChantAddToChatViews];
}

- (void) insertInChatConsoles:(id <JVChatViewController>) view atIndex:(NSUInteger) index {
	[self scriptErrorChantAddToChatViews];
}

- (void) removeFromChatConsolesAtIndex:(NSUInteger) index {
	[self removeFromChatViewsAtIndex:index withClass:[JVChatConsolePanel class]];
}

- (void) replaceInChatConsoles:(id <JVChatViewController>) view atIndex:(NSUInteger) index {
	[self scriptErrorChantAddToChatViews];
}

#pragma mark -

- (NSArray *) indicesOfObjectsByEvaluatingRangeSpecifier:(NSRangeSpecifier *) specifier {
	NSString *key = [specifier key];

	if( [key isEqualToString:@"chatViews"] || [key isEqualToString:@"chatRooms"] || [key isEqualToString:@"directChats"] || [key isEqualToString:@"chatConsoles"] || [key isEqualToString:@"chatTranscripts"] ) {
		NSScriptObjectSpecifier *startSpec = [specifier startSpecifier];
		NSScriptObjectSpecifier *endSpec = [specifier endSpecifier];
		NSString *startKey = [startSpec key];
		NSString *endKey = [endSpec key];
		NSArray *chatViews = [self chatViews];

		if( ! startSpec && ! endSpec ) return nil;

		if( ! [chatViews count] ) return @[];

		if( ( ! startSpec || [startKey isEqualToString:@"chatViews"] || [startKey isEqualToString:@"chatRooms"] || [startKey isEqualToString:@"directChats"] || [startKey isEqualToString:@"chatConsoles"] || [startKey isEqualToString:@"chatTranscripts"] ) && ( ! endSpec || [endKey isEqualToString:@"chatViews"] || [endKey isEqualToString:@"chatRooms"] || [endKey isEqualToString:@"directChats"] || [endKey isEqualToString:@"chatConsoles"] || [endKey isEqualToString:@"chatTranscripts"] ) ) {
			NSUInteger startIndex = 0;
			NSUInteger endIndex = 0;

			// The strategy here is going to be to find the index of the start and stop object in the full chat views array, regardless of what its key is.  Then we can find what we're looking for in that range of the chat views key (weeding out objects we don't want, if necessary).
			// First find the index of the first start object in the chat views array
			if( startSpec ) {
				id startObject = [startSpec objectsByEvaluatingSpecifier];
				if( [startObject isKindOfClass:[NSArray class]] ) {
					if( ! [(NSArray *)startObject count] ) startObject = nil;
					else startObject = startObject[0];
				}
				if( ! startObject ) return nil;
				startIndex = [chatViews indexOfObjectIdenticalTo:startObject];
				if( startIndex == NSNotFound ) return nil;
			}

			// Now find the index of the last end object in the chat views array
			if( endSpec ) {
				id endObject = [endSpec objectsByEvaluatingSpecifier];
				if( [endObject isKindOfClass:[NSArray class]] ) {
					if( ! [(NSArray *)endObject count] ) endObject = nil;
					else endObject = [endObject lastObject];
				}
				if( ! endObject ) return nil;
				endIndex = [chatViews indexOfObjectIdenticalTo:endObject];
				if( endIndex == NSNotFound ) return nil;
			} else endIndex = ( [chatViews count] - 1 );

			// Accept backwards ranges gracefully
			if( endIndex < startIndex ) {
				NSUInteger temp = endIndex;
				endIndex = startIndex;
				startIndex = temp;
			}

			// Now startIndex and endIndex specify the end points of the range we want within the main array.
			// We will traverse the range and pick the objects we want.
			// We do this by getting each object and seeing if it actually appears in the real key that we are trying to evaluate in.
			NSMutableArray *result = [NSMutableArray array];
			BOOL keyIsGeneric = [key isEqualToString:@"chatViews"];
			NSArray *rangeKeyObjects = ( keyIsGeneric ? nil : [self valueForKey:key] );
			NSUInteger curKeyIndex = 0;
			id obj = nil;

			for( NSUInteger i = startIndex; i <= endIndex; i++ ) {
				if( keyIsGeneric ) {
					[result addObject:@(i)];
				} else {
					obj = chatViews[i];
					curKeyIndex = [rangeKeyObjects indexOfObjectIdenticalTo:obj];
					if( curKeyIndex != NSNotFound )
						[result addObject:@(curKeyIndex)];
				}
			}

			return result;
		}
	}

	return nil;
}

- (NSArray *) indicesOfObjectsByEvaluatingRelativeSpecifier:(NSRelativeSpecifier *) specifier {
	NSString *key = [specifier key];

	if( [key isEqualToString:@"chatViews"] || [key isEqualToString:@"chatRooms"] || [key isEqualToString:@"directChats"] || [key isEqualToString:@"chatConsoles"] || [key isEqualToString:@"chatTranscripts"] ) {
		NSScriptObjectSpecifier *baseSpec = [specifier baseSpecifier];
		NSString *baseKey = [baseSpec key];
		NSArray *chatViews = [self chatViews];
		NSRelativePosition relPos = [specifier relativePosition];

		if( ! baseSpec ) return nil;

		if( ! [chatViews count] ) return @[];

		if( [baseKey isEqualToString:@"chatViews"] || [baseKey isEqualToString:@"chatRooms"] || [baseKey isEqualToString:@"directChats"] || [baseKey isEqualToString:@"chatConsoles"] || [baseKey isEqualToString:@"chatTranscripts"] ) {
			NSUInteger baseIndex = 0;

			// The strategy here is going to be to find the index of the base object in the full chat views array, regardless of what its key is.  Then we can find what we're looking for before or after it.
			// First find the index of the first or last base object in the master array
			// Base specifiers are to be evaluated within the same container as the relative specifier they are the base of. That's this container.

			id baseObject = [baseSpec objectsByEvaluatingWithContainers:self];
			if( [baseObject isKindOfClass:[NSArray class]] ) {
				NSUInteger baseCount = [(NSArray *)baseObject count];
				if( baseCount ) {
					if( relPos == NSRelativeBefore ) baseObject = baseObject[0];
					else baseObject = baseObject[( baseCount - 1 )];
				} else baseObject = nil;
			}

			if( ! baseObject ) return nil;

			baseIndex = [chatViews indexOfObjectIdenticalTo:baseObject];
			if( baseIndex == NSNotFound ) return nil;

			// Now baseIndex specifies the base object for the relative spec in the master array.
			// We will start either right before or right after and look for an object that matches the type we want.
			// We do this by getting each object and seeing if it actually appears in the real key that we are trying to evaluate in.
			NSMutableArray *result = [NSMutableArray array];
			BOOL keyIsGeneric = [key isEqualToString:@"chatViews"];
			NSArray *relKeyObjects = ( keyIsGeneric ? nil : [self valueForKey:key] );
			NSUInteger curKeyIndex = 0, viewCount = [chatViews count];
			id obj = nil;

			if( relPos == NSRelativeBefore ) baseIndex--;
			else baseIndex++;

			while( baseIndex < viewCount ) {
				if( keyIsGeneric ) {
					[result addObject:@(baseIndex)];
					break;
				} else {
					obj = chatViews[baseIndex];
					curKeyIndex = [relKeyObjects indexOfObjectIdenticalTo:obj];
					if( curKeyIndex != NSNotFound ) {
						[result addObject:@(curKeyIndex)];
						break;
					}
				}

				if( relPos == NSRelativeBefore ) baseIndex--;
				else baseIndex++;
			}

			return result;
		}
	}

	return nil;
}

- (NSArray *) indicesOfObjectsByEvaluatingObjectSpecifier:(NSScriptObjectSpecifier *) specifier {
	if( [specifier isKindOfClass:[NSRangeSpecifier class]] ) {
		return [self indicesOfObjectsByEvaluatingRangeSpecifier:(NSRangeSpecifier *) specifier];
	} else if( [specifier isKindOfClass:[NSRelativeSpecifier class]] ) {
		return [self indicesOfObjectsByEvaluatingRelativeSpecifier:(NSRelativeSpecifier *) specifier];
	}
	return nil;
}
@end
