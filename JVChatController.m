#import <Cocoa/Cocoa.h>
#import <ChatCore/MVChatConnection.h>
#import <ChatCore/NSAttributedStringAdditions.h>
#import <AGRegex/AGRegex.h>

#import "JVChatController.h"
#import "MVApplicationController.h"
#import "JVChatWindowController.h"
#import "JVNotificationController.h"
#import "JVChatTranscript.h"
#import "JVDirectChat.h"
#import "JVChatRoom.h"
#import "JVChatConsole.h"
#import "KAIgnoreRule.h"

#import <libxml/parser.h>

static JVChatController *sharedInstance = nil;

@interface JVChatController (JVChatControllerPrivate)
- (void) _addWindowController:(JVChatWindowController *) windowController;
- (void) _addViewControllerToPreferedWindowController:(id <JVChatViewController>) controller;
- (BOOL) _handlePrivateMessageOnConnection:(MVChatConnection *) connection withInfo:(NSDictionary *) info;
- (BOOL) _ignoreUser:(NSString *) name withMessage:(NSAttributedString *) message inRoom:(NSString *) room withConnection:(MVChatConnection *) connection;
@end

#pragma mark -

@implementation JVChatController
+ (JVChatController *) defaultManager {
	extern JVChatController *sharedInstance;
	if( ! sharedInstance && [MVApplicationController isTerminating] ) return nil;
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] init] ) );
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_chatWindows = [[NSMutableArray array] retain];
		_chatControllers = [[NSMutableArray array] retain];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _joinedRoom: ) name:MVChatConnectionJoinedRoomNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _leftRoom: ) name:MVChatConnectionLeftRoomNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _existingRoomMembers: ) name:MVChatConnectionRoomExistingMemberListNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _joinWhoList: ) name:MVChatConnectionGotJoinWhoListNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _memberJoinedRoom: ) name:MVChatConnectionUserJoinedRoomNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _memberLeftRoom: ) name:MVChatConnectionUserLeftRoomNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _memberQuit: ) name:MVChatConnectionUserQuitNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _memberInvitedToRoom: ) name:MVChatConnectionInvitedToRoomNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _memberNicknameChanged: ) name:MVChatConnectionUserNicknameChangedNotification object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _memberModeChanged: ) name:MVChatConnectionGotMemberModeNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _memberKicked: ) name:MVChatConnectionUserKickedFromRoomNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _kickedFromRoom: ) name:MVChatConnectionKickedFromRoomNotification object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _newBan: ) name:MVChatConnectionNewBanNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _removedBan: ) name:MVChatConnectionRemovedBanNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _banlistReceived: ) name:MVChatConnectionBanlistReceivedNotification object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _gotPrivateMessage: ) name:MVChatConnectionGotPrivateMessageNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _gotRoomMessage: ) name:MVChatConnectionGotRoomMessageNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _roomTopicChanged: ) name:MVChatConnectionGotRoomTopicNotification object:nil];
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
	JVChatWindowController *windowController = [[[JVChatWindowController alloc] initWithWindowNibName:nil] autorelease];
	[self _addWindowController:windowController];
	return [[windowController retain] autorelease];
}

- (void) disposeChatWindowController:(JVChatWindowController *) controller {
	NSParameterAssert( controller != nil );
	NSAssert1( [_chatWindows containsObject:controller], @"%@ is not a member of chat controller.", controller );

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

- (JVChatRoom *) chatViewControllerForRoom:(NSString *) room withConnection:(MVChatConnection *) connection ifExists:(BOOL) exists {
	id <JVChatViewController> ret = nil;
	NSEnumerator *enumerator = nil;

	NSParameterAssert( room != nil );
	NSParameterAssert( connection != nil );

	enumerator = [_chatControllers objectEnumerator];
	while( ( ret = [enumerator nextObject] ) )
		if( [ret isMemberOfClass:[JVChatRoom class]] && [ret connection] == connection && [[(JVChatRoom *)ret target] caseInsensitiveCompare:room] == NSOrderedSame )
			break;

	if( ! ret && ! exists ) {
		if( ( ret = [[[JVChatRoom alloc] initWithTarget:room forConnection:connection] autorelease] ) ) {
			[_chatControllers addObject:ret];
			[self _addViewControllerToPreferedWindowController:ret];
		}
	}

	return [[ret retain] autorelease];
}

- (JVDirectChat *) chatViewControllerForUser:(NSString *) user withConnection:(MVChatConnection *) connection ifExists:(BOOL) exists {
	id <JVChatViewController> ret = nil;
	NSEnumerator *enumerator = nil;

	NSParameterAssert( user != nil );
	NSParameterAssert( connection != nil );

	enumerator = [_chatControllers objectEnumerator];
	while( ( ret = [enumerator nextObject] ) )
		if( [ret isMemberOfClass:[JVDirectChat class]] && [ret connection] == connection && [[(JVDirectChat *)ret target] caseInsensitiveCompare:user] == NSOrderedSame )
			break;

	if( ! ret && ! exists ) {
		if( ( ret = [[[JVDirectChat alloc] initWithTarget:user forConnection:connection] autorelease] ) ) {
			[_chatControllers addObject:ret];
			[self _addViewControllerToPreferedWindowController:ret];
		}
	}

	return [[ret retain] autorelease];
}

- (JVChatTranscript *) chatViewControllerForTranscript:(NSString *) filename {
	id <JVChatViewController> ret = nil;
	if( ( ret = [[[JVChatTranscript alloc] initWithTranscript:filename] autorelease] ) ) {
		[_chatControllers addObject:ret];
		[self _addViewControllerToPreferedWindowController:ret];
	}
	return [[ret retain] autorelease];
}

- (JVChatConsole *) chatConsoleForConnection:(MVChatConnection *) connection ifExists:(BOOL) exists {
	id <JVChatViewController> ret = nil;
	NSEnumerator *enumerator = nil;

	NSParameterAssert( connection != nil );

	enumerator = [_chatControllers objectEnumerator];
	while( ( ret = [enumerator nextObject] ) )
		if( [ret isMemberOfClass:[JVChatConsole class]] && [ret connection] == connection )
			break;

	if( ! ret && ! exists ) {
		if( ( ret = [[[JVChatConsole alloc] initWithConnection:connection] autorelease] ) ) {
			[_chatControllers addObject:ret];
			[self _addViewControllerToPreferedWindowController:ret];
		}
	}

	return [[ret retain] autorelease];
}

- (void) disposeViewController:(id <JVChatViewController>) controller {
	NSParameterAssert( controller != nil );
	NSAssert1( [_chatControllers containsObject:controller], @"%@ is not a member of chat controller.", controller );
	if( [controller respondsToSelector:@selector( willDispose )] )
		[(NSObject *)controller willDispose];
	[[controller windowController] removeChatViewController:controller];
	[_chatControllers removeObject:controller];
}

#pragma mark -

- (IBAction) detachView:(id) sender {
	id <JVChatViewController> view = [[[sender representedObject] retain] autorelease];
	JVChatWindowController *windowController = [self newChatWindowController];
	[[view windowController] removeChatViewController:view];
	[windowController addChatViewController:view];
	[windowController showChatViewController:view];
}

#pragma mark -
#pragma mark Ignores

- (void) addIgnore:(NSString *) inIgnoreName withKey:(NSString *) ignoreKeyExpression inRooms:(NSArray *) rooms usesRegex:(BOOL) regex isMember:(BOOL) member {
	[_ignoreRules setObject:[KAInternalIgnoreRule ruleWithString:ignoreKeyExpression inRooms:rooms usesRegex:regex ignoreMember:member] forKey:inIgnoreName];
}


- (BOOL) shouldIgnoreUser:(NSString *) user inRoom:(NSString *) room {
	BOOL ignoreThisUser = NO;
	NSEnumerator *kenum = [_ignoreRules keyEnumerator];
	NSString *key = nil;
	KAInternalIgnoreRule *rule = nil;

	while( key = [kenum nextObject] ) {
		if( [key isEqualToString:user] ) ignoreThisUser = YES;

		rule = [_ignoreRules objectForKey:key];
		
		if( [rule regex] && !ignoreThisUser && [rule isMember] ) {
			AGRegex *matchString = [AGRegex regexWithPattern:[rule key] options:AGRegexCaseInsensitive];
			if( [matchString findInString:key] ) ignoreThisUser = YES;
		}
	}

	return ignoreThisUser;
}

- (BOOL) shouldIgnoreMessage:(NSAttributedString *) message inRoom:(NSString *) room {
	BOOL ignoreThisMessage = NO;
	NSEnumerator *oenum = [_ignoreRules objectEnumerator];
	KAInternalIgnoreRule *rule = nil;

	while( rule = [oenum nextObject] ) {		
		if( [rule regex] && ![rule isMember] ) {
			AGRegex *matchPattern = [AGRegex regexWithPattern:[rule key] options:AGRegexCaseInsensitive];
			if( [matchPattern findInString:[rule key]] ) ignoreThisMessage = YES;
		} else if( [[rule key] isEqualToString:[message string]] ) ignoreThisMessage = YES;
	}

	return ignoreThisMessage;
}

- (BOOL) shouldIgnoreMessage:(NSAttributedString *) message fromUser:(NSString *)user inRoom:(NSString *) room {
	return ( [self shouldIgnoreUser:user inRoom:room] || [self shouldIgnoreMessage:message inRoom:room] );
}

@end

#pragma mark -

@implementation JVChatController (JVChatControllerPrivate)
- (void) _joinedRoom:(NSNotification *) notification {
	JVChatRoom *room = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:NO];
	[room joined];
}

- (void) _leftRoom:(NSNotification *) notification {
	if( ! [[notification object] isConnected] ) return;
	JVChatRoom *room = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	if( ! room ) return;
	[room parting];
	if( ! [room keepAfterPart] )
		[self disposeViewController:room];
}

- (void) _existingRoomMembers:(NSNotification *) notification {
	JVChatRoom *controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	[controller addExistingMembersToChat:[[notification userInfo] objectForKey:@"members"]];
}

- (void) _joinWhoList:(NSNotification *) notification {
	JVChatRoom *controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	[controller addWhoInformationToMembers:[[notification userInfo] objectForKey:@"list"]];
}

- (void) _memberJoinedRoom:(NSNotification *) notification {
	JVChatRoom *controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	[controller addMemberToChat:[[notification userInfo] objectForKey:@"who"] withInformation:[[notification userInfo] objectForKey:@"info"]];
}

- (void) _memberLeftRoom:(NSNotification *) notification {
	JVChatRoom *controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	[controller removeChatMember:[[notification userInfo] objectForKey:@"who"] withReason:[[notification userInfo] objectForKey:@"reason"]];
}

- (void) _memberQuit:(NSNotification *) notification {
	NSString *who = [[notification userInfo] objectForKey:@"who"];
	NSEnumerator *enumerator = [[self chatViewControllersWithConnection:[notification object]] objectEnumerator];
	id controller = nil;
	
	while( ( controller = [enumerator nextObject] ) ) {
		if( [controller isKindOfClass:[JVChatRoom class]] ) {
			[controller removeChatMember:[[notification userInfo] objectForKey:@"who"] withReason:[[notification userInfo] objectForKey:@"reason"]];
		} else if( [controller isKindOfClass:[JVDirectChat class]] && [[controller target] isEqualToString:who] ) {
			// [controller unavailable];
		}
	}
}

- (void) _memberInvitedToRoom:(NSNotification *) notification {
	NSString *room = [[notification userInfo] objectForKey:@"room"];
	NSString *by = [[notification userInfo] objectForKey:@"from"];
	MVChatConnection *connection = [notification object];

	NSString *title = NSLocalizedString( @"Chat Room Invite", "member invited to room title" );
	NSString *message = [NSString stringWithFormat:NSLocalizedString( @"You were invited to join %@ by %@. Would you like to accept this invitation and join this room?", "you were invited to join a chat room status message" ), room, by];

	// This should not be modal. Fix sometime.
	if( NSRunInformationalAlertPanel( title, message, NSLocalizedString( @"Join", "join button" ), NSLocalizedString( @"Decline", "decline button" ), nil ) == NSOKButton )
		[connection joinChatRoom:room];

	NSMutableDictionary *context = [NSMutableDictionary dictionary];
	[context setObject:NSLocalizedString( @"Invited to Chat", "bubble title invited to room" ) forKey:@"title"];
	[context setObject:[NSString stringWithFormat:NSLocalizedString( @"You were invited to %@ by %@.", "bubble message invited to room" ), room, by] forKey:@"description"];
	[context setObject:[connection nickname] forKey:@"performedOn"];
	[context setObject:by forKey:@"performedBy"];
	[[JVNotificationController defaultManager] performNotification:@"JVChatRoomInvite" withContextInfo:context];
}

- (void) _memberNicknameChanged:(NSNotification *) notification {
	id controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	[(JVChatRoom *)controller changeChatMember:[[notification userInfo] objectForKey:@"oldNickname"] to:[[notification userInfo] objectForKey:@"newNickname"]];

	controller = [self chatViewControllerForUser:[[notification userInfo] objectForKey:@"oldNickname"] withConnection:[notification object] ifExists:YES];
	[controller setTarget:[[notification userInfo] objectForKey:@"newNickname"]];
}

- (void) _memberModeChanged:(NSNotification *) notification {
	JVChatRoom *controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	BOOL enabled = [[[notification userInfo] objectForKey:@"enabled"] boolValue];
	MVChatMemberMode mode = [[[notification userInfo] objectForKey:@"mode"] unsignedIntValue];

	if( enabled && mode == MVChatMemberOperatorMode ) {
		[controller promoteChatMember:[[notification userInfo] objectForKey:@"who"] by:[[notification userInfo] objectForKey:@"by"]];
	} else if( ! enabled && mode == MVChatMemberOperatorMode ) {
		[controller demoteChatMember:[[notification userInfo] objectForKey:@"who"] by:[[notification userInfo] objectForKey:@"by"]];
	} else if( enabled && mode == MVChatMemberVoiceMode ) {
		[controller voiceChatMember:[[notification userInfo] objectForKey:@"who"] by:[[notification userInfo] objectForKey:@"by"]];
	} else if( ! enabled && mode == MVChatMemberVoiceMode ) {
		[controller devoiceChatMember:[[notification userInfo] objectForKey:@"who"] by:[[notification userInfo] objectForKey:@"by"]];
	}
}

- (void) _memberKicked:(NSNotification *) notification {
	JVChatRoom *controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	[controller chatMember:[[notification userInfo] objectForKey:@"who"] kickedBy:[[notification userInfo] objectForKey:@"by"] forReason:[[notification userInfo] objectForKey:@"reason"]];
}

- (void) _kickedFromRoom:(NSNotification *) notification {
	JVChatRoom *controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	[controller kickedFromChatBy:[[notification userInfo] objectForKey:@"by"] forReason:[[notification userInfo] objectForKey:@"reason"]];
}

- (void) _newBan:(NSNotification *) notification {
	JVChatRoom *controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	[controller newBan:[[notification userInfo] objectForKey:@"ban"] by:[[notification userInfo] objectForKey:@"by"]];
}

- (void) _removedBan:(NSNotification *) notification {
	JVChatRoom *controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	[controller removedBan:[[notification userInfo] objectForKey:@"ban"] by:[[notification userInfo] objectForKey:@"by"]];
}

- (void) _banlistReceived:(NSNotification *) notification {
	JVChatRoom *controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	[controller banlistReceived];
}

- (void) _gotPrivateMessage:(NSNotification *) notification {
	BOOL continueNotify = YES;
	if ( [[[notification userInfo] objectForKey:@"auto"] boolValue] ) {
		continueNotify = ! [self _handlePrivateMessageOnConnection:[notification object] withInfo:[notification userInfo]];
	}
	
	if ( continueNotify ) {
		JVDirectChat *controller = [self chatViewControllerForUser:[[notification userInfo] objectForKey:@"from"] withConnection:[notification object] ifExists:NO];
		[controller addMessageToDisplay:[[notification userInfo] objectForKey:@"message"] fromUser:[[notification userInfo] objectForKey:@"from"] asAction:[[[notification userInfo] objectForKey:@"action"] boolValue]];
	}
}

- (void) _gotRoomMessage:(NSNotification *) notification {
		JVChatRoom *controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
		[controller addMessageToDisplay:[[notification userInfo] objectForKey:@"message"] fromUser:[[notification userInfo] objectForKey:@"from"] asAction:[[[notification userInfo] objectForKey:@"action"] boolValue]];
}

- (void) _roomTopicChanged:(NSNotification *) notification {
	JVChatRoom *controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	id author = [[notification userInfo] objectForKey:@"author"];
	if( [author isMemberOfClass:[NSNull class]] ) author = nil;
	[controller changeTopic:[[notification userInfo] objectForKey:@"topic"] by:author displayChange:( ! [[[notification userInfo] objectForKey:@"justJoined"] boolValue] )];
}

- (void) _addWindowController:(JVChatWindowController *) windowController {
	[_chatWindows addObject:windowController];
}

- (void) _addViewControllerToPreferedWindowController:(id <JVChatViewController>) controller {
	JVChatWindowController *windowController = nil;
	id <JVChatViewController> viewController = nil;
	Class modeClass = NULL;
	NSEnumerator *enumerator = nil;

	NSParameterAssert( controller != nil );

	int mode = [[NSUserDefaults standardUserDefaults] integerForKey:[NSStringFromClass( [controller class] ) stringByAppendingString:@"PreferredOpenMode"]];
	BOOL groupByServer = (BOOL) mode & 32;
	mode &= ~32;

	switch( mode ) {
	default:
	case 0:
		windowController = nil;
		break;
	case 1:
		enumerator = [_chatWindows objectEnumerator];
		while( ( windowController = [enumerator nextObject] ) )
			if( [[windowController window] isMainWindow] || ! [[NSApplication sharedApplication] isActive] )
				break;
		if( ! windowController ) windowController = [_chatWindows lastObject];
		break;
	case 2:
		modeClass = [JVChatRoom class];
		goto groupByClass;
	case 3:
		modeClass = [JVDirectChat class];
		goto groupByClass;
	case 4:
		modeClass = [JVChatTranscript class];
		goto groupByClass;
	case 5:
		modeClass = [JVChatConsole class];
		goto groupByClass;
	groupByClass:
		if( groupByServer ) {
			enumerator = [[self chatViewControllersOfClass:modeClass] objectEnumerator];
			while( ( viewController = [enumerator nextObject] ) ) {
				if( [viewController connection] == [controller connection] ) {
					windowController = [viewController windowController];
					break;
				}
			}
		} else {
		    if( [[self chatViewControllersOfClass:modeClass] count ] > 0 ) {
				NSMutableSet *tempSet = [[[self chatViewControllersOfClass:modeClass] mutableCopy] autorelease];
				[tempSet removeObject:controller];
				windowController = [[tempSet anyObject] windowController];
		    }
		}
		break;
	}

	if( ! windowController ) windowController = [self newChatWindowController];

	[windowController addChatViewController:controller];
	[windowController showChatViewController:controller];
}

- (BOOL) _handlePrivateMessageOnConnection:(MVChatConnection *) connection withInfo:(NSDictionary *) info {
	NSString *user = [info objectForKey:@"from"];
	NSData *message = [info objectForKey:@"message"];
	BOOL hideFromUser = YES;

	if( [self chatViewControllerForUser:user withConnection:connection ifExists:YES] ) hideFromUser = NO;

	NSString *curMsg = [[[NSString alloc] initWithData:message encoding:[connection encoding]] autorelease];
	if( ! curMsg ) curMsg = [NSString stringWithCString:[message bytes] length:[message length]];

	if( [user isEqualToString:@"NickServ"] ) {
		if( [curMsg rangeOfString:@"password accepted" options:NSCaseInsensitiveSearch].location != NSNotFound ) {
			NSMutableDictionary *context = [NSMutableDictionary dictionary];
			[context setObject:NSLocalizedString( @"You Have Been Identified", "identified bubble title" ) forKey:@"title"];
			[context setObject:[NSString stringWithFormat:@"%@ on %@", curMsg, [connection server]] forKey:@"description"];
			[context setObject:[NSImage imageNamed:@"Keychain"] forKey:@"image"];
			[context setObject:[connection nickname] forKey:@"performedOn"];
			[context setObject:user forKey:@"performedBy"];
			[[JVNotificationController defaultManager] performNotification:@"JVNickNameIdentifiedWithServer" withContextInfo:context];
		}
	}

	if( [user isEqualToString:@"MemoServ"] ) {
		if( [curMsg rangeOfString:@"new memo" options:NSCaseInsensitiveSearch].location != NSNotFound && [curMsg rangeOfString:@" no " options:NSCaseInsensitiveSearch].location == NSNotFound ) {
			NSAttributedString *curAMsg = [NSAttributedString attributedStringWithHTMLFragment:[NSString stringWithFormat:@"<span style=\"font-size: 11px; font-family: Lucida Grande, san-serif\">%@ on %@</span>", curMsg, [connection server]] baseURL:NULL]; 
			NSMutableDictionary *context = [NSMutableDictionary dictionary];
			[context setObject:NSLocalizedString( @"You Have New Memos", "new memos bubble title" ) forKey:@"title"];
			[context setObject:curAMsg forKey:@"description"];
			[context setObject:[NSImage imageNamed:@"Stickies"] forKey:@"image"];
			[context setObject:[connection nickname] forKey:@"performedOn"];
			[context setObject:user forKey:@"performedBy"];
			[context setObject:self forKey:@"target"];
			[context setObject:NSStringFromSelector( @selector( _checkMemos: ) ) forKey:@"action"];
			[context setObject:connection forKey:@"representedObject"];
			[[JVNotificationController defaultManager] performNotification:@"JVNewMemosFromServer" withContextInfo:context];
		}	
	}

	return hideFromUser;
}

- (IBAction) _checkMemos:(id) sender {
	MVChatConnection *connection = [sender representedObject];
	NSAttributedString *message = [[[NSAttributedString alloc] initWithString:@"read all"] autorelease];
	[connection sendMessage:message withEncoding:[connection encoding] toUser:@"MemoServ" asAction:NO];
	[self chatViewControllerForUser:@"MemoServ" withConnection:connection ifExists:NO];
}

- (BOOL) _ignoreUser:(NSString *) name withMessage:(NSAttributedString *) message inRoom:(NSString *) room withConnection:(MVChatConnection *) connection {
	BOOL wasIgnored = NO;
	// second check for ignore: if the object in the dictionary is nil, we ignore the user everywhere
	// if we have an array we check that the array contains our current room and ignore them

	if( [self shouldIgnoreUser:name inRoom:room] ) {
		NSArray *ignoredRooms = [[_ignoreRules objectForKey:name] channels];

		if( ! ignoredRooms ) {
			// send an ignored Notificatoin
			NSMutableDictionary *context = [NSMutableDictionary dictionary];
			[context setObject:NSLocalizedString( @"User Message Ignored", "user ignored bubble title" ) forKey:@"title"];
			[context setObject:[NSString stringWithFormat:@"%@'s message was ignored in %@", name, room] forKey:@"description"];
			[context setObject:[NSImage imageNamed:@"activity"] forKey:@"image"];
			[context setObject:name forKey:@"performedOn"];
			[context setObject:[connection nickname] forKey:@"performedBy"];
			[context setObject:connection forKey:@"representedObject"];
			[[JVNotificationController defaultManager] performNotification:@"JVUserMessageIgnored" withContextInfo:context];
			wasIgnored = YES;
		}
	} else if( [self shouldIgnoreMessage:message inRoom:room] ) {
		// send an ignored Notificatoin
		NSMutableDictionary *context = [NSMutableDictionary dictionary];
		[context setObject:NSLocalizedString( @"Message Ignored", "message ignored bubble title" ) forKey:@"title"];
		[context setObject:[NSString stringWithFormat:@"%@'s message was ignored in %@", name, room] forKey:@"description"];
		[context setObject:[NSImage imageNamed:@"activity"] forKey:@"image"];
		[context setObject:name forKey:@"performedOn"];
		[context setObject:[connection nickname] forKey:@"performedBy"];
		[context setObject:connection forKey:@"representedObject"];
		[[JVNotificationController defaultManager] performNotification:@"JVMessageIgnored" withContextInfo:context];
	}

	return wasIgnored;
}
@end

#pragma mark -

@implementation JVChatWindowController (JVChatWindowControllerObjectSpecifier)
- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[JVChatController class]];
	NSScriptObjectSpecifier *container = [[JVChatController defaultManager] objectSpecifier];
	return [[[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"chatWindows" uniqueID:[self uniqueIdentifier]] autorelease];
}
@end

#pragma mark -

@implementation JVChatTranscript (JVChatTranscriptObjectSpecifier)
- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[JVChatController class]];
	NSScriptObjectSpecifier *container = [[JVChatController defaultManager] objectSpecifier];
	return [[[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"chatViews" uniqueID:[self uniqueIdentifier]] autorelease];
}
@end

#pragma mark -

@implementation JVChatConsole (JVChatConsoleObjectSpecifier)
- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[JVChatController class]];
	NSScriptObjectSpecifier *container = [[JVChatController defaultManager] objectSpecifier];
	return [[[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"chatViews" uniqueID:[self uniqueIdentifier]] autorelease];
}
@end

#pragma mark -

@implementation JVChatController (JVChatControllerScripting)
- (JVChatWindowController *) newChatWindowScriptCommand:(NSScriptCommand *) command {
	return [self newChatWindowController];
}

- (void) startChatScriptCommand:(NSScriptCommand *) command {
	MVChatConnection *connection = [[command evaluatedArguments] objectForKey:@"connection"];
	NSString *user = [[command evaluatedArguments] objectForKey:@"user"];

	if( ! [user length] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid user nickname."];
		return;
	}

	if( ! connection || ! [connection isConnected] ) {
		[NSException raise:NSInvalidArgumentException format:@"Invalid conenction or it is not connected."];
		return;
	}

	[self chatViewControllerForUser:user withConnection:connection ifExists:NO];
}

#pragma mark -

- (NSArray *) chatWindows {
	return _chatWindows;
}

- (JVChatWindowController *) valueInChatWindowsAtIndex:(unsigned) index {
	return [_chatWindows objectAtIndex:index];
}

- (JVChatWindowController *) valueInChatWindowsWithUniqueID:(id) identifier {
	NSEnumerator *enumerator = [_chatWindows objectEnumerator];
	JVChatWindowController *window = nil;

	while( ( window = [enumerator nextObject] ) )
		if( [[window uniqueIdentifier] isEqual:identifier] )
			return window;

	return nil;
}

- (void) addInChatWindows:(JVChatWindowController *) window {
	[self _addWindowController:window];
}

- (void) insertInChatWindows:(JVChatWindowController *) window {
	[self _addWindowController:window];
}

- (void) insertInChatWindows:(JVChatWindowController *) window atIndex:(unsigned) index {
	[self _addWindowController:window];
}

- (void) removeFromChatWindowsAtIndex:(unsigned) index {
	JVChatWindowController *window = [[self chatWindows] objectAtIndex:index];
	[[window window] orderOut:nil];
	[self disposeChatWindowController:window];
}

- (void) replaceInChatWindows:(JVChatWindowController *) window atIndex:(unsigned) index {
	[NSException raise:NSOperationNotSupportedForKeyException format:@"Can't replace a chat window."];
}

#pragma mark -

- (void) raiseCantAddChatViewsException {
	[NSException raise:NSOperationNotSupportedForKeyException format:@"Can't insert a chat view. Read only."];
}

#pragma mark -

- (NSArray *) chatViews {
	return _chatControllers;
}

- (id <JVChatViewController>) valueInChatViewsAtIndex:(unsigned) index {
	return [_chatControllers objectAtIndex:index];
}

- (id <JVChatViewController>) valueInChatViewsWithUniqueID:(id) identifier {
	NSEnumerator *enumerator = [_chatControllers objectEnumerator];
	id <JVChatViewController, JVChatListItemScripting> view = nil;

	while( ( view = [enumerator nextObject] ) )
		if( [[view uniqueIdentifier] isEqual:identifier] )
			return view;

	return nil;
}

- (id <JVChatViewController>) valueInChatViewsWithName:(NSString *) name {
	NSEnumerator *enumerator = [_chatControllers objectEnumerator];
	id <JVChatViewController> view = nil;

	while( ( view = [enumerator nextObject] ) )
		if( [[view title] isEqualToString:name] )
			return view;

	return nil;
}

- (void) addInChatViews:(id <JVChatViewController>) view {
	[self raiseCantAddChatViewsException];
}

- (void) insertInChatViews:(id <JVChatViewController>) view {
	[self raiseCantAddChatViewsException];
}

- (void) insertInChatViews:(id <JVChatViewController>) view atIndex:(unsigned) index {
	[self raiseCantAddChatViewsException];
}

- (void) removeFromChatViewsAtIndex:(unsigned) index {
	id <JVChatViewController> view = [_chatControllers objectAtIndex:index];
	[self disposeViewController:view];
}

- (void) replaceInChatViews:(id <JVChatViewController>) view atIndex:(unsigned) index {
	[self raiseCantAddChatViewsException];
}

#pragma mark -

- (NSArray *) chatViewsWithClass:(Class) class {
	NSMutableArray *ret = [NSMutableArray array];
	id <JVChatViewController> item = nil;
	NSEnumerator *enumerator = nil;

	enumerator = [_chatControllers objectEnumerator];
	while( ( item = [enumerator nextObject] ) )
		if( [item isMemberOfClass:class] )
			[ret addObject:item];

	return ret;
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
	[self disposeViewController:view];
}

#pragma mark -

- (NSArray *) chatRooms {
	return [self chatViewsWithClass:[JVChatRoom class]];
}

- (id <JVChatViewController>) valueInChatRoomsAtIndex:(unsigned) index {
	return [self valueInChatViewsAtIndex:index withClass:[JVChatRoom class]];
}

- (id <JVChatViewController>) valueInChatRoomsWithUniqueID:(id) identifier {
	return [self valueInChatViewsWithUniqueID:identifier andClass:[JVChatRoom class]];
}

- (id <JVChatViewController>) valueInChatRoomsWithName:(NSString *) name {
	return [self valueInChatViewsWithName:name andClass:[JVChatRoom class]];
}

- (void) addInChatRooms:(id <JVChatViewController>) view {
	[self raiseCantAddChatViewsException];
}

- (void) insertInChatRooms:(id <JVChatViewController>) view {
	[self raiseCantAddChatViewsException];
}

- (void) insertInChatRooms:(id <JVChatViewController>) view atIndex:(unsigned) index {
	[self raiseCantAddChatViewsException];
}

- (void) removeFromChatRoomsAtIndex:(unsigned) index {
	[self removeFromChatViewsAtIndex:index withClass:[JVChatRoom class]];
}

- (void) replaceInChatRooms:(id <JVChatViewController>) view atIndex:(unsigned) index {
	[self raiseCantAddChatViewsException];
}

#pragma mark -

- (NSArray *) directChats {
	return [self chatViewsWithClass:[JVDirectChat class]];
}

- (id <JVChatViewController>) valueInDirectChatsAtIndex:(unsigned) index {
	return [self valueInChatViewsAtIndex:index withClass:[JVDirectChat class]];
}

- (id <JVChatViewController>) valueInDirectChatsWithUniqueID:(id) identifier {
	return [self valueInChatViewsWithUniqueID:identifier andClass:[JVDirectChat class]];
}

- (id <JVChatViewController>) valueInDirectChatsWithName:(NSString *) name {
	return [self valueInChatViewsWithName:name andClass:[JVDirectChat class]];
}

- (void) addInDirectChats:(id <JVChatViewController>) view {
	[self raiseCantAddChatViewsException];
}

- (void) insertInDirectChats:(id <JVChatViewController>) view {
	[self raiseCantAddChatViewsException];
}

- (void) insertInDirectChats:(id <JVChatViewController>) view atIndex:(unsigned) index {
	[self raiseCantAddChatViewsException];
}

- (void) removeFromDirectChatsAtIndex:(unsigned) index {
	[self removeFromChatViewsAtIndex:index withClass:[JVDirectChat class]];
}

- (void) replaceInDirectChats:(id <JVChatViewController>) view atIndex:(unsigned) index {
	[self raiseCantAddChatViewsException];
}

#pragma mark -

- (NSArray *) chatTranscripts {
	return [self chatViewsWithClass:[JVChatTranscript class]];
}

- (id <JVChatViewController>) valueInChatTranscriptsAtIndex:(unsigned) index {
	return [self valueInChatViewsAtIndex:index withClass:[JVChatTranscript class]];
}

- (id <JVChatViewController>) valueInChatTranscriptsWithUniqueID:(id) identifier {
	return [self valueInChatViewsWithUniqueID:identifier andClass:[JVChatTranscript class]];
}

- (id <JVChatViewController>) valueInChatTranscriptsWithName:(NSString *) name {
	return [self valueInChatViewsWithName:name andClass:[JVChatTranscript class]];
}

- (void) addInChatTranscripts:(id <JVChatViewController>) view {
	[self raiseCantAddChatViewsException];
}

- (void) insertInChatTranscripts:(id <JVChatViewController>) view {
	[self raiseCantAddChatViewsException];
}

- (void) insertInChatTranscripts:(id <JVChatViewController>) view atIndex:(unsigned) index {
	[self raiseCantAddChatViewsException];
}

- (void) removeFromChatTranscriptsAtIndex:(unsigned) index {
	[self removeFromChatViewsAtIndex:index withClass:[JVChatTranscript class]];
}

- (void) replaceInChatTranscripts:(id <JVChatViewController>) view atIndex:(unsigned) index {
	[self raiseCantAddChatViewsException];
}

#pragma mark -

- (NSArray *) chatConsoles {
	return [self chatViewsWithClass:[JVChatConsole class]];
}

- (id <JVChatViewController>) valueInChatConsolesAtIndex:(unsigned) index {
	return [self valueInChatViewsAtIndex:index withClass:[JVChatConsole class]];
}

- (id <JVChatViewController>) valueInChatConsolesWithUniqueID:(id) identifier {
	return [self valueInChatViewsWithUniqueID:identifier andClass:[JVChatConsole class]];
}

- (id <JVChatViewController>) valueInChatConsolesWithName:(NSString *) name {
	return [self valueInChatViewsWithName:name andClass:[JVChatConsole class]];
}

- (void) addInChatConsoles:(id <JVChatViewController>) view {
	[self raiseCantAddChatViewsException];
}

- (void) insertInChatConsoles:(id <JVChatViewController>) view {
	[self raiseCantAddChatViewsException];
}

- (void) insertInChatConsoles:(id <JVChatViewController>) view atIndex:(unsigned) index {
	[self raiseCantAddChatViewsException];
}

- (void) removeFromChatConsolesAtIndex:(unsigned) index {
	[self removeFromChatViewsAtIndex:index withClass:[JVChatConsole class]];
}

- (void) replaceInChatConsoles:(id <JVChatViewController>) view atIndex:(unsigned) index {
	[self raiseCantAddChatViewsException];
}

#pragma mark -

- (NSArray *) indicesOfObjectsByEvaluatingRangeSpecifier:(NSRangeSpecifier *) specifier {
	NSString *key = [specifier key];

	if( [key isEqual:@"chatViews"] || [key isEqual:@"chatRooms"] || [key isEqual:@"directChats"] || [key isEqual:@"chatConsoles"] || [key isEqual:@"chatTranscripts"] ) {
		NSScriptObjectSpecifier *startSpec = [specifier startSpecifier];
		NSScriptObjectSpecifier *endSpec = [specifier endSpecifier];
		NSString *startKey = [startSpec key];
		NSString *endKey = [endSpec key];
		NSArray *chatViews = [self chatViews];

		if( ! startSpec && ! endSpec ) return nil;

		if( ! [chatViews count] ) [NSArray array];

		if( ( ! startSpec || [startKey isEqual:@"chatViews"] || [startKey isEqual:@"chatRooms"] || [startKey isEqual:@"directChats"] || [startKey isEqual:@"chatConsoles"] || [startKey isEqual:@"chatTranscripts"] ) && ( ! endSpec || [endKey isEqual:@"chatViews"] || [endKey isEqual:@"chatRooms"] || [endKey isEqual:@"directChats"] || [endKey isEqual:@"chatConsoles"] || [endKey isEqual:@"chatTranscripts"] ) ) {
			int startIndex = 0;
			int endIndex = 0;

			// The strategy here is going to be to find the index of the start and stop object in the full graphics array, regardless of what its key is.  Then we can find what we're looking for in that range of the graphics key (weeding out objects we don't want, if necessary).
			// First find the index of the first start object in the graphics array
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

			// Now find the index of the last end object in the graphics array
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

	if( [key isEqual:@"chatViews"] || [key isEqual:@"chatRooms"] || [key isEqual:@"directChats"] || [key isEqual:@"chatConsoles"] || [key isEqual:@"chatTranscripts"] ) {
		NSScriptObjectSpecifier *baseSpec = [specifier baseSpecifier];
		NSString *baseKey = [baseSpec key];
		NSArray *chatViews = [self chatViews];
		NSRelativePosition relPos = [specifier relativePosition];

		if( ! baseSpec ) return nil;

		if( ! [chatViews count] ) return [NSArray array];

		if( [baseKey isEqual:@"chatViews"] || [baseKey isEqual:@"chatRooms"] || [baseKey isEqual:@"directChats"] || [baseKey isEqual:@"chatConsoles"] || [baseKey isEqual:@"chatTranscripts"] ) {
			int baseIndex = 0;

			// The strategy here is going to be to find the index of the base object in the full graphics array, regardless of what its key is.  Then we can find what we're looking for before or after it.
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
			BOOL keyIsGeneric = [key isEqual:@"chatViews"];
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