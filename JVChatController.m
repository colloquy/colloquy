#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatUser.h>
#import <ChatCore/NSAttributedStringAdditions.h>

#import "JVChatController.h"
#import "MVConnectionsController.h"
#import "JVChatWindowController.h"
#import "JVTabbedChatWindowController.h"
#import "JVNotificationController.h"
#import "JVChatTranscriptPanel.h"
#import "JVSmartTranscriptPanel.h"
#import "JVDirectChatPanel.h"
#import "JVChatRoomPanel.h"
#import "JVChatConsolePanel.h"
#import "JVChatMessage.h"
#import "JVChatRoomMember.h"

#import <libxml/parser.h>

static JVChatController *sharedInstance = nil;
static NSMenu *smartTranscriptMenu = nil;

@interface JVChatController (JVChatControllerPrivate)
- (void) _addWindowController:(JVChatWindowController *) windowController;
- (void) _addViewControllerToPreferedWindowController:(id <JVChatViewController>) controller andFocus:(BOOL) focus;
@end

#pragma mark -

@implementation JVChatController
+ (JVChatController *) defaultManager {
	extern JVChatController *sharedInstance;
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] init] ) );
}

+ (NSMenu *) smartTranscriptMenu {
	extern NSMenu *smartTranscriptMenu;
	[self refreshSmartTranscriptMenu];
	return smartTranscriptMenu;
}

+ (void) refreshSmartTranscriptMenu {
	extern NSMenu *smartTranscriptMenu;
	if( ! smartTranscriptMenu ) smartTranscriptMenu = [[NSMenu alloc] initWithTitle:@""];

	NSMenuItem *menuItem = nil;
	NSEnumerator *enumerator = [[[[smartTranscriptMenu itemArray] copy] autorelease] objectEnumerator];
	while( ( menuItem = [enumerator nextObject] ) )
		[smartTranscriptMenu removeItem:menuItem];

	NSMutableArray *items = [NSMutableArray arrayWithArray:[[[self defaultManager] smartTranscripts] allObjects]];
	[items sortUsingSelector:@selector( compare: )];

	enumerator = [items objectEnumerator];

	JVSmartTranscriptPanel *panel = nil;

	while( ( panel = [enumerator nextObject] ) ) {
		menuItem = [[[NSMenuItem alloc] initWithTitle:[panel title] action:@selector( showView: ) keyEquivalent:@""] autorelease];
		if( [panel newMessagesWaiting] ) [menuItem setImage:[NSImage imageNamed:@"smartTranscriptTabActivity"]];
		else [menuItem setImage:[NSImage imageNamed:@"smartTranscriptTab"]];
		[menuItem setTarget:[self defaultManager]];
		[menuItem setRepresentedObject:panel];
		[smartTranscriptMenu addItem:menuItem];
	}

	if( ! [items count] ) {
		menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"No Smart Transcripts", "no smart transcripts menu title" ) action:NULL keyEquivalent:@""] autorelease];
		[smartTranscriptMenu addItem:menuItem];
	}

	[smartTranscriptMenu addItem:[NSMenuItem separatorItem]];

	menuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"New Smart Transcript...", "new smart transcript menu title" ) action:@selector( _newSmartTranscript: ) keyEquivalent:@"n"] autorelease];
	[menuItem setKeyEquivalentModifierMask:(NSCommandKeyMask | NSAlternateKeyMask)];
	[menuItem setTarget:[JVChatController defaultManager]];
	[smartTranscriptMenu addItem:menuItem];
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_chatWindows = [[NSMutableArray array] retain];
		_chatControllers = [[NSMutableArray array] retain];

		NSEnumerator *smartTranscriptsEnumerator = [[[NSUserDefaults standardUserDefaults] objectForKey:@"JVSmartTranscripts"] objectEnumerator];
		NSData *archivedSmartTranscript = nil;
		while( ( archivedSmartTranscript = [smartTranscriptsEnumerator nextObject] ) )
			[_chatControllers addObject:[NSKeyedUnarchiver unarchiveObjectWithData:archivedSmartTranscript]];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _joinedRoom: ) name:MVChatRoomJoinedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _invitedToRoom: ) name:MVChatRoomInvitedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _gotPrivateMessage: ) name:MVChatConnectionGotPrivateMessageNotification object:nil];
	}
	return self;
}

- (void) dealloc {
	extern JVChatController *sharedInstance;

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if( self == sharedInstance ) sharedInstance = nil;

	[_chatWindows release];
	[_chatControllers release];

	_chatWindows = nil;
	_chatControllers = nil;

	[super dealloc];
}

#pragma mark -

- (NSSet *) allChatWindowControllers {
	return [[[NSSet setWithArray:_chatWindows] retain] autorelease];
}

- (JVChatWindowController *) newChatWindowController {
	JVChatWindowController *windowController = nil;
	if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVUseTabbedWindows"] )
		windowController = [[[JVTabbedChatWindowController alloc] init] autorelease];
	else windowController = [[[JVChatWindowController alloc] init] autorelease];
	[self _addWindowController:windowController];
	return [[windowController retain] autorelease];
}

- (void) disposeChatWindowController:(JVChatWindowController *) controller {
	NSParameterAssert( controller != nil );

	id view = nil;
	NSEnumerator *enumerator = [[controller allChatViewControllers] objectEnumerator];
	while( ( view = [enumerator nextObject] ) )
		[self disposeViewController:view];

	[_chatWindows removeObject:controller];
}

#pragma mark -

- (NSSet *) allChatViewControllers {
	return [[[NSSet setWithArray:_chatControllers] retain] autorelease];
}

- (NSSet *) chatViewControllersWithConnection:(MVChatConnection *) connection {
	NSMutableSet *ret = [NSMutableSet set];
	id <JVChatViewController> item = nil;
	NSEnumerator *enumerator = nil;

	NSParameterAssert( connection != nil );

	enumerator = [_chatControllers objectEnumerator];
	while( ( item = [enumerator nextObject] ) )
		if( [item connection] == connection )
			[ret addObject:item];

	return [[ret retain] autorelease];
}

- (NSSet *) chatViewControllersOfClass:(Class) class {
	NSMutableSet *ret = [NSMutableSet set];
	id <JVChatViewController> item = nil;
	NSEnumerator *enumerator = nil;

	NSParameterAssert( class != NULL );

	enumerator = [_chatControllers objectEnumerator];
	while( ( item = [enumerator nextObject] ) )
		if( [item isMemberOfClass:class] )
			[ret addObject:item];

	return [[ret retain] autorelease];
}

- (NSSet *) chatViewControllersKindOfClass:(Class) class {
	NSMutableSet *ret = [NSMutableSet set];
	id <JVChatViewController> item = nil;
	NSEnumerator *enumerator = nil;

	NSParameterAssert( class != NULL );

	enumerator = [_chatControllers objectEnumerator];
	while( ( item = [enumerator nextObject] ) )
		if( [item isKindOfClass:class] )
			[ret addObject:item];

	return [[ret retain] autorelease];
}

#pragma mark -

- (JVChatRoomPanel *) chatViewControllerForRoom:(MVChatRoom *) room ifExists:(BOOL) exists {
	NSParameterAssert( room != nil );

	NSEnumerator *enumerator = [_chatControllers objectEnumerator];
	id ret = nil;

	while( ( ret = [enumerator nextObject] ) )
		if( [ret isMemberOfClass:[JVChatRoomPanel class]] && [[ret target] isEqual:room] )
			break;

	if( ! ret && ! exists ) {
		if( ( ret = [[[JVChatRoomPanel alloc] initWithTarget:room] autorelease] ) ) {
			[_chatControllers addObject:ret];
			[self _addViewControllerToPreferedWindowController:ret andFocus:YES];
		}
	}

	return [[ret retain] autorelease];
}

- (JVDirectChatPanel *) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists {
	return [self chatViewControllerForUser:user ifExists:exists userInitiated:YES];
}

- (JVDirectChatPanel *) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists userInitiated:(BOOL) initiated {
	NSParameterAssert( user != nil );

	NSEnumerator *enumerator = [_chatControllers objectEnumerator];
	id ret = nil;

	while( ( ret = [enumerator nextObject] ) )
		if( [ret isMemberOfClass:[JVDirectChatPanel class]] && [[ret target] isEqual:user] )
			break;

	if( ! ret && ! exists ) {
		if( ( ret = [[[JVDirectChatPanel alloc] initWithTarget:user] autorelease] ) ) {
			[_chatControllers addObject:ret];
			[self _addViewControllerToPreferedWindowController:ret andFocus:initiated];
		}
	}

	return [[ret retain] autorelease];
}

- (JVChatTranscriptPanel *) chatViewControllerForTranscript:(NSString *) filename {
	id ret = nil;
	if( ( ret = [[[JVChatTranscriptPanel alloc] initWithTranscript:filename] autorelease] ) ) {
		[_chatControllers addObject:ret];
		[self _addViewControllerToPreferedWindowController:ret andFocus:YES];
	}
	return [[ret retain] autorelease];
}

#pragma mark -

- (JVSmartTranscriptPanel *) newSmartTranscript {
	JVSmartTranscriptPanel *ret = nil;
	if( ( ret = [[[JVSmartTranscriptPanel alloc] initWithSettings:nil] autorelease] ) ) {
		[_chatControllers addObject:ret];
		[self _addViewControllerToPreferedWindowController:ret andFocus:YES];
		[ret editSettings:nil];
	}
	return [[ret retain] autorelease];
}

- (NSSet *) smartTranscripts {
	return [self chatViewControllersOfClass:[JVSmartTranscriptPanel class]];
}

- (void) saveSmartTranscripts {
	NSMutableArray *smartTranscripts = [NSMutableArray array];
	NSEnumerator *enumerator = [[self smartTranscripts] objectEnumerator];
	JVSmartTranscriptPanel *smartTranscript = nil;

	while( ( smartTranscript = [enumerator nextObject] ) )
		[smartTranscripts addObject:[NSKeyedArchiver archivedDataWithRootObject:smartTranscript]];

	[[self class] refreshSmartTranscriptMenu];
	[[NSUserDefaults standardUserDefaults] setObject:smartTranscripts forKey:@"JVSmartTranscripts"];
}

- (void) disposeSmartTranscript:(JVSmartTranscriptPanel *) panel {
	NSParameterAssert( panel != nil );

	if( [panel respondsToSelector:@selector( willDispose )] )
		[(NSObject *)panel willDispose];

	[[panel windowController] removeChatViewController:panel];
	[_chatControllers removeObject:panel];

	[self saveSmartTranscripts];
}

#pragma mark -

- (JVChatConsolePanel *) chatConsoleForConnection:(MVChatConnection *) connection ifExists:(BOOL) exists {
	NSParameterAssert( connection != nil );

	NSEnumerator *enumerator = [_chatControllers objectEnumerator];
	id <JVChatViewController> ret = nil;

	while( ( ret = [enumerator nextObject] ) )
		if( [ret isMemberOfClass:[JVChatConsolePanel class]] && [ret connection] == connection )
			break;

	if( ! ret && ! exists ) {
		if( ( ret = [[[JVChatConsolePanel alloc] initWithConnection:connection] autorelease] ) ) {
			[_chatControllers addObject:ret];
			[self _addViewControllerToPreferedWindowController:ret andFocus:YES];
		}
	}

	return [[ret retain] autorelease];
}

#pragma mark -

- (void) disposeViewController:(id <JVChatViewController>) controller {
	NSParameterAssert( controller != nil );

	if( [controller respondsToSelector:@selector( willDispose )] )
		[(NSObject *)controller willDispose];

	[[controller windowController] removeChatViewController:controller];

	if( [controller isKindOfClass:[JVSmartTranscriptPanel class]] ) return;

	[_chatControllers removeObject:controller];
}

- (void) detachViewController:(id <JVChatViewController>) controller {
	NSParameterAssert( controller != nil );

	[[controller retain] autorelease];

	JVChatWindowController *windowController = [self newChatWindowController];
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
	else [self _addViewControllerToPreferedWindowController:view andFocus:YES];
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
	NSEnumerator *renum = [[[MVConnectionsController defaultManager] ignoreRulesForConnection:[view connection]] objectEnumerator];
	KAIgnoreRule *rule = nil;

	while( ( ignoreResult == JVNotIgnored ) && ( ( rule = [renum nextObject] ) ) )
		ignoreResult = [rule matchUser:user message:[message string] inView:view];

	return ignoreResult;
}
@end

#pragma mark -

@implementation JVChatController (JVChatControllerPrivate)
- (void) _joinedRoom:(NSNotification *) notification {
	MVChatRoom *rm = [notification object];
	if( ! [[MVConnectionsController defaultManager] managesConnection:[rm connection]] ) return;
	JVChatRoomPanel *room = [self chatViewControllerForRoom:rm ifExists:NO];
	[room joined];
}

- (void) _invitedToRoom:(NSNotification *) notification {
	NSString *room = [[notification userInfo] objectForKey:@"room"];
	MVChatUser *user = [[notification userInfo] objectForKey:@"user"];
	MVChatConnection *connection = [notification object];

	if( ! [[MVConnectionsController defaultManager] managesConnection:connection] ) return;

	NSString *title = NSLocalizedString( @"Chat Room Invite", "member invited to room title" );
	NSString *message = [NSString stringWithFormat:NSLocalizedString( @"You were invited to join %@ by %@. Would you like to accept this invitation and join this room?", "you were invited to join a chat room status message" ), room, [user nickname]];

	if( NSRunInformationalAlertPanel( title, message, NSLocalizedString( @"Join", "join button" ), NSLocalizedString( @"Decline", "decline button" ), nil ) == NSOKButton )
		[connection joinChatRoomNamed:room];

	NSMutableDictionary *context = [NSMutableDictionary dictionary];
	[context setObject:NSLocalizedString( @"Invited to Chat", "bubble title invited to room" ) forKey:@"title"];
	[context setObject:[NSString stringWithFormat:NSLocalizedString( @"You were invited to %@ by %@.", "bubble message invited to room" ), room, [user nickname]] forKey:@"description"];
	[[JVNotificationController defaultManager] performNotification:@"JVChatRoomInvite" withContextInfo:context];
}

- (void) _gotPrivateMessage:(NSNotification *) notification {
	BOOL hideFromUser = NO;
	MVChatUser *user = [notification object];
	NSData *message = [[notification userInfo] objectForKey:@"message"];

	if( ! [[MVConnectionsController defaultManager] managesConnection:[user connection]] ) return;

	if( [[[notification userInfo] objectForKey:@"notice"] boolValue] ) {
		MVChatConnection *connection = [user connection];

		if( ! [self chatViewControllerForUser:user ifExists:YES] )
			hideFromUser = YES;

		if( [[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatAlwaysShowNotices"] )
			hideFromUser = NO;

		NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:[connection encoding]], @"StringEncoding", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageColors"]], @"IgnoreFontColors", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageFormatting"]], @"IgnoreFontTraits", [NSFont systemFontOfSize:11.], @"BaseFont", nil];
		NSAttributedString *messageString = [NSAttributedString attributedStringWithChatFormat:message options:options];
		if( ! messageString ) {
			[options setObject:[NSNumber numberWithUnsignedInt:[NSString defaultCStringEncoding]] forKey:@"StringEncoding"];
			messageString = [NSAttributedString attributedStringWithChatFormat:message options:options];
		}

		if( [[user nickname] isEqualToString:@"NickServ"] || [[user nickname] isEqualToString:@"MemoServ"] ) {
			if( [[user nickname] isEqualToString:@"NickServ"] ) {
				if( [[messageString string] rangeOfString:@"password accepted" options:NSCaseInsensitiveSearch].location != NSNotFound ) {
					NSMutableDictionary *context = [NSMutableDictionary dictionary];
					[context setObject:NSLocalizedString( @"You Have Been Identified", "identified bubble title" ) forKey:@"title"];
					[context setObject:[NSString stringWithFormat:@"%@ on %@", [messageString string], [connection server]] forKey:@"description"];
					[context setObject:[NSImage imageNamed:@"Keychain"] forKey:@"image"];
					[[JVNotificationController defaultManager] performNotification:@"JVNickNameIdentifiedWithServer" withContextInfo:context];
				}
			} else if( [[user nickname] isEqualToString:@"MemoServ"] ) {
				if( [[messageString string] rangeOfString:@"new memo" options:NSCaseInsensitiveSearch].location != NSNotFound && [[messageString string] rangeOfString:@" no " options:NSCaseInsensitiveSearch].location == NSNotFound ) {
					NSMutableDictionary *context = [NSMutableDictionary dictionary];
					[context setObject:NSLocalizedString( @"You Have New Memos", "new memos bubble title" ) forKey:@"title"];
					[context setObject:messageString forKey:@"description"];
					[context setObject:[NSImage imageNamed:@"Stickies"] forKey:@"image"];
					[context setObject:self forKey:@"target"];
					[context setObject:NSStringFromSelector( @selector( _checkMemos: ) ) forKey:@"action"];
					[context setObject:connection forKey:@"representedObject"];
					[[JVNotificationController defaultManager] performNotification:@"JVNewMemosFromServer" withContextInfo:context];
				}
			}
		} else {
			NSMutableDictionary *context = [NSMutableDictionary dictionary];
			[context setObject:[NSString stringWithFormat:NSLocalizedString( @"Notice from %@", "notice message from user title" ), [user displayName]] forKey:@"title"];
			[context setObject:messageString forKey:@"description"];
			[context setObject:[NSImage imageNamed:@"activityNewImportant"] forKey:@"image"];
			NSString *type = ( hideFromUser ? @"JVChatUnhandledNoticeMessage" : @"JVChatNoticeMessage" );
			[[JVNotificationController defaultManager] performNotification:type withContextInfo:context];
		}
	}

	if( ! hideFromUser && ( [self shouldIgnoreUser:user withMessage:nil inView:nil] == JVNotIgnored ) ) {
		JVDirectChatPanel *controller = [self chatViewControllerForUser:user ifExists:NO userInitiated:NO];
		JVChatMessageType type = ( [[[notification userInfo] objectForKey:@"notice"] boolValue] ? JVChatMessageNoticeType : JVChatMessageNormalType );
		[controller addMessageToDisplay:message fromUser:user asAction:[[[notification userInfo] objectForKey:@"action"] boolValue] withIdentifier:[[notification userInfo] objectForKey:@"identifier"] andType:type];
	}
}

- (void) _addWindowController:(JVChatWindowController *) windowController {
	[_chatWindows addObject:windowController];
}

- (void) _addViewControllerToPreferedWindowController:(id <JVChatViewController>) controller andFocus:(BOOL) focus {
	JVChatWindowController *windowController = nil;
	id <JVChatViewController> viewController = nil;
	Class modeClass = NULL;
	NSEnumerator *enumerator = nil;
	BOOL kindOfClass = NO;

	NSParameterAssert( controller != nil );

	int mode = [[NSUserDefaults standardUserDefaults] integerForKey:[NSStringFromClass( [controller class] ) stringByAppendingString:@"PreferredOpenMode"]];
	BOOL groupByServer = (BOOL) mode & 32;
	mode &= ~32;

	switch( mode ) {
	default:
	case 0:
	case 1:
		enumerator = [_chatWindows objectEnumerator];
		while( ( windowController = [enumerator nextObject] ) )
			if( [[windowController window] isMainWindow] || ! [[NSApplication sharedApplication] isActive] )
				break;
		if( ! windowController ) windowController = [_chatWindows lastObject];
		break;
	case 2:
		modeClass = [JVChatRoomPanel class];
		goto groupByClass;
	case 3:
		modeClass = [JVDirectChatPanel class];
		goto groupByClass;
	case 4:
		modeClass = [JVChatTranscriptPanel class];
		goto groupByClass;
	case 5:
		modeClass = [JVChatConsolePanel class];
		goto groupByClass;
	case 6:
		modeClass = [JVDirectChatPanel class];
		kindOfClass = YES;
		goto groupByClass;
	groupByClass:
		if( groupByServer ) {
			if( kindOfClass ) enumerator = [[self chatViewControllersKindOfClass:modeClass] objectEnumerator];
			else enumerator = [[self chatViewControllersOfClass:modeClass] objectEnumerator];
			while( ( viewController = [enumerator nextObject] ) ) {
				if( controller != viewController && [viewController connection] == [controller connection] ) {
					windowController = [viewController windowController];
					if( windowController ) break;
				}
			}
		} else {
			if( kindOfClass ) enumerator = [[self chatViewControllersKindOfClass:modeClass] objectEnumerator];
			else enumerator = [[self chatViewControllersOfClass:modeClass] objectEnumerator];
			while( ( viewController = [enumerator nextObject] ) ) {
				if( controller != viewController ) {
					windowController = [viewController windowController];
					if( windowController ) break;
				}
			}
		}
		break;
	}

	if( ! windowController ) windowController = [self newChatWindowController];

	if( [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSCommandKeyMask ) focus = NO;
	if( [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSShiftKeyMask ) focus = NO;

	[windowController addChatViewController:controller];
	if( focus || [[windowController allChatViewControllers] count] == 1 ) {
		[windowController showChatViewController:controller];
		if( focus ) [[windowController window] makeKeyAndOrderFront:nil];
	}

	if( ! [[windowController window] isVisible] )
		[[windowController window] orderFront:nil];
}

- (IBAction) _checkMemos:(id) sender {
	MVChatConnection *connection = [sender representedObject];
	NSAttributedString *message = [[[NSAttributedString alloc] initWithString:@"read all"] autorelease];
	MVChatUser *user = [connection chatUserWithUniqueIdentifier:@"MemoServ"];
	[user sendMessage:message withEncoding:[connection encoding] asAction:NO];
	[self chatViewControllerForUser:user ifExists:NO];
}

- (IBAction) _newSmartTranscript:(id) sender {
	[[JVChatController defaultManager] newSmartTranscript];
}
@end

#pragma mark -

@implementation JVChatTranscriptPanel (JVChatTranscriptObjectSpecifier)
- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[NSApplication class]];
	NSScriptObjectSpecifier *container = [[NSApplication sharedApplication] objectSpecifier];
	return [[[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"chatTranscripts" uniqueID:[self uniqueIdentifier]] autorelease];
}
@end

#pragma mark -

@implementation JVDirectChatPanel (JVDirectChatPanelObjectSpecifier)
- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[NSApplication class]];
	NSScriptObjectSpecifier *container = [[NSApplication sharedApplication] objectSpecifier];
	return [[[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"directChats" uniqueID:[self uniqueIdentifier]] autorelease];
}
@end

#pragma mark -

@implementation JVChatRoomPanel (JVChatRoomPanelObjectSpecifier)
- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[NSApplication class]];
	NSScriptObjectSpecifier *container = [[NSApplication sharedApplication] objectSpecifier];
	return [[[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"chatRooms" uniqueID:[self uniqueIdentifier]] autorelease];
}
@end

#pragma mark -

@implementation JVChatConsolePanel (JVChatConsolePanelObjectSpecifier)
- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[NSApplication class]];
	NSScriptObjectSpecifier *container = [[NSApplication sharedApplication] objectSpecifier];
	return [[[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"chatConsoles" uniqueID:[self uniqueIdentifier]] autorelease];
}
@end

#pragma mark -

@interface JVStartChatScriptCommand : NSScriptCommand {}
@end

#pragma mark -

@implementation JVStartChatScriptCommand
- (id) performDefaultImplementation {
	NSDictionary *args = [self evaluatedArguments];
	id target = [args objectForKey:@"target"];

	if( target && [target isKindOfClass:[NSString class]] ) {
		MVChatConnection *connection = [args objectForKey:@"connection"];
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

	JVDirectChatPanel *panel = [[JVChatController defaultManager] chatViewControllerForUser:target ifExists:NO];
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
	return [[[JVChatController defaultManager] allChatViewControllers] allObjects];
}

- (id <JVChatViewController>) valueInChatViewsAtIndex:(unsigned) index {
	return [[self chatViews] objectAtIndex:index];
}

- (id <JVChatViewController>) valueInChatViewsWithUniqueID:(id) identifier {
	NSEnumerator *enumerator = [[[JVChatController defaultManager] allChatViewControllers] objectEnumerator];
	id <JVChatViewController, JVChatListItemScripting> view = nil;

	while( ( view = [enumerator nextObject] ) )
		if( [view conformsToProtocol:@protocol( JVChatListItemScripting )] &&
			[[view uniqueIdentifier] isEqual:identifier] ) return view;

	return nil;
}

- (id <JVChatViewController>) valueInChatViewsWithName:(NSString *) name {
	NSEnumerator *enumerator = [[[JVChatController defaultManager] allChatViewControllers] objectEnumerator];
	id <JVChatViewController> view = nil;

	while( ( view = [enumerator nextObject] ) )
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

- (void) insertInChatViews:(id <JVChatViewController>) view atIndex:(unsigned) index {
	[self scriptErrorChantAddToChatViews];
}

- (void) removeFromChatViewsAtIndex:(unsigned) index {
	id <JVChatViewController> view = [[self chatViews] objectAtIndex:index];
	if( view ) [[JVChatController defaultManager] disposeViewController:view];
}

- (void) replaceInChatViews:(id <JVChatViewController>) view atIndex:(unsigned) index {
	[self scriptErrorChantAddToChatViews];
}

#pragma mark -

- (NSArray *) chatViewsWithClass:(Class) class {
	return [[[JVChatController defaultManager] chatViewControllersOfClass:class] allObjects];
}

- (id <JVChatViewController>) valueInChatViewsAtIndex:(unsigned) index withClass:(Class) class {
	return [[self chatViewsWithClass:class] objectAtIndex:index];
}

- (id <JVChatViewController>) valueInChatViewsWithUniqueID:(id) identifier andClass:(Class) class {
	return [self valueInChatViewsWithUniqueID:identifier];
}

- (id <JVChatViewController>) valueInChatViewsWithName:(NSString *) name andClass:(Class) class {
	NSEnumerator *enumerator = [[self chatViewsWithClass:class] objectEnumerator];
	id <JVChatViewController> view = nil;

	while( ( view = [enumerator nextObject] ) )
		if( [[view title] isEqualToString:name] )
			return view;

	return nil;
}

- (void) removeFromChatViewsAtIndex:(unsigned) index withClass:(Class) class {
	id <JVChatViewController> view = [[self chatViewsWithClass:class] objectAtIndex:index];
	if( view ) [[JVChatController defaultManager] disposeViewController:view];
}

#pragma mark -

- (NSArray *) chatRooms {
	return [self chatViewsWithClass:[JVChatRoomPanel class]];
}

- (id <JVChatViewController>) valueInChatRoomsAtIndex:(unsigned) index {
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

- (void) insertInChatRooms:(id <JVChatViewController>) view atIndex:(unsigned) index {
	[self scriptErrorChantAddToChatViews];
}

- (void) removeFromChatRoomsAtIndex:(unsigned) index {
	[self removeFromChatViewsAtIndex:index withClass:[JVChatRoomPanel class]];
}

- (void) replaceInChatRooms:(id <JVChatViewController>) view atIndex:(unsigned) index {
	[self scriptErrorChantAddToChatViews];
}

#pragma mark -

- (NSArray *) directChats {
	return [self chatViewsWithClass:[JVDirectChatPanel class]];
}

- (id <JVChatViewController>) valueInDirectChatsAtIndex:(unsigned) index {
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

- (void) insertInDirectChats:(id <JVChatViewController>) view atIndex:(unsigned) index {
	[self scriptErrorChantAddToChatViews];
}

- (void) removeFromDirectChatsAtIndex:(unsigned) index {
	[self removeFromChatViewsAtIndex:index withClass:[JVDirectChatPanel class]];
}

- (void) replaceInDirectChats:(id <JVChatViewController>) view atIndex:(unsigned) index {
	[self scriptErrorChantAddToChatViews];
}

#pragma mark -

- (NSArray *) chatTranscripts {
	return [self chatViewsWithClass:[JVChatTranscriptPanel class]];
}

- (id <JVChatViewController>) valueInChatTranscriptsAtIndex:(unsigned) index {
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

- (void) insertInChatTranscripts:(id <JVChatViewController>) view atIndex:(unsigned) index {
	[self scriptErrorChantAddToChatViews];
}

- (void) removeFromChatTranscriptsAtIndex:(unsigned) index {
	[self removeFromChatViewsAtIndex:index withClass:[JVChatTranscriptPanel class]];
}

- (void) replaceInChatTranscripts:(id <JVChatViewController>) view atIndex:(unsigned) index {
	[self scriptErrorChantAddToChatViews];
}

#pragma mark -

- (NSArray *) chatConsoles {
	return [self chatViewsWithClass:[JVChatConsolePanel class]];
}

- (id <JVChatViewController>) valueInChatConsolesAtIndex:(unsigned) index {
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

- (void) insertInChatConsoles:(id <JVChatViewController>) view atIndex:(unsigned) index {
	[self scriptErrorChantAddToChatViews];
}

- (void) removeFromChatConsolesAtIndex:(unsigned) index {
	[self removeFromChatViewsAtIndex:index withClass:[JVChatConsolePanel class]];
}

- (void) replaceInChatConsoles:(id <JVChatViewController>) view atIndex:(unsigned) index {
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

		if( ! [chatViews count] ) [NSArray array];

		if( ( ! startSpec || [startKey isEqualToString:@"chatViews"] || [startKey isEqualToString:@"chatRooms"] || [startKey isEqualToString:@"directChats"] || [startKey isEqualToString:@"chatConsoles"] || [startKey isEqualToString:@"chatTranscripts"] ) && ( ! endSpec || [endKey isEqualToString:@"chatViews"] || [endKey isEqualToString:@"chatRooms"] || [endKey isEqualToString:@"directChats"] || [endKey isEqualToString:@"chatConsoles"] || [endKey isEqualToString:@"chatTranscripts"] ) ) {
			int startIndex = 0;
			int endIndex = 0;

			// The strategy here is going to be to find the index of the start and stop object in the full chat views array, regardless of what its key is.  Then we can find what we're looking for in that range of the chat views key (weeding out objects we don't want, if necessary).
			// First find the index of the first start object in the chat views array
			if( startSpec ) {
				id startObject = [startSpec objectsByEvaluatingSpecifier];
				if( [startObject isKindOfClass:[NSArray class]] ) {
					if( ! [(NSArray *)startObject count] ) startObject = nil;
					else startObject = [startObject objectAtIndex:0];
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
				int temp = endIndex;
				endIndex = startIndex;
				startIndex = temp;
			}

			// Now startIndex and endIndex specify the end points of the range we want within the main array.
			// We will traverse the range and pick the objects we want.
			// We do this by getting each object and seeing if it actually appears in the real key that we are trying to evaluate in.
			NSMutableArray *result = [NSMutableArray array];
			BOOL keyIsGeneric = [key isEqualToString:@"chatViews"];
			NSArray *rangeKeyObjects = ( keyIsGeneric ? nil : [self valueForKey:key] );
			unsigned curKeyIndex = 0, i = 0;
			id obj = nil;

			for( i = startIndex; i <= endIndex; i++ ) {
				if( keyIsGeneric ) {
					[result addObject:[NSNumber numberWithInt:i]];
				} else {
					obj = [chatViews objectAtIndex:i];
					curKeyIndex = [rangeKeyObjects indexOfObjectIdenticalTo:obj];
					if( curKeyIndex != NSNotFound )
						[result addObject:[NSNumber numberWithInt:curKeyIndex]];
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

		if( ! [chatViews count] ) return [NSArray array];

		if( [baseKey isEqualToString:@"chatViews"] || [baseKey isEqualToString:@"chatRooms"] || [baseKey isEqualToString:@"directChats"] || [baseKey isEqualToString:@"chatConsoles"] || [baseKey isEqualToString:@"chatTranscripts"] ) {
			int baseIndex = 0;

			// The strategy here is going to be to find the index of the base object in the full chat views array, regardless of what its key is.  Then we can find what we're looking for before or after it.
			// First find the index of the first or last base object in the master array
			// Base specifiers are to be evaluated within the same container as the relative specifier they are the base of. That's this container.

			id baseObject = [baseSpec objectsByEvaluatingWithContainers:self];
			if( [baseObject isKindOfClass:[NSArray class]] ) {
				int baseCount = [(NSArray *)baseObject count];
				if( baseCount ) {
					if( relPos == NSRelativeBefore ) baseObject = [baseObject objectAtIndex:0];
					else baseObject = [baseObject objectAtIndex:( baseCount - 1 )];
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
			unsigned curKeyIndex = 0, viewCount = [chatViews count];
			id obj = nil;

			if( relPos == NSRelativeBefore ) baseIndex--;
			else baseIndex++;

			while( baseIndex >= 0 && baseIndex < viewCount ) {
				if( keyIsGeneric ) {
					[result addObject:[NSNumber numberWithInt:baseIndex]];
					break;
				} else {
					obj = [chatViews objectAtIndex:baseIndex];
					curKeyIndex = [relKeyObjects indexOfObjectIdenticalTo:obj];
					if( curKeyIndex != NSNotFound ) {
						[result addObject:[NSNumber numberWithInt:curKeyIndex]];
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