#import <Cocoa/Cocoa.h>
#import <ChatCore/MVChatConnection.h>

#import "JVChatController.h"
#import "JVChatWindowController.h"
#import "JVChatTranscript.h"
#import "JVDirectChat.h"
#import "JVChatRoom.h"
#import "JVChatConsole.h"

#import <libxml/parser.h>

static JVChatController *sharedInstance = nil;

@interface JVChatController (JVChatControllerPrivate)
- (void) _addWindowController:(JVChatWindowController *) windowController;
- (void) _addViewControllerToPreferedWindowController:(id <JVChatViewController>) controller;
@end

#pragma mark -

@implementation JVChatController
+ (JVChatController *) defaultManager {
	extern JVChatController *sharedInstance;
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] init] ) );
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_chatWindows = [[NSMutableSet set] retain];
		_chatControllers = [[NSMutableSet set] retain];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _joinedRoom: ) name:MVChatConnectionJoinedRoomNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _leftRoom: ) name:MVChatConnectionLeftRoomNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _memberJoinedRoom: ) name:MVChatConnectionUserJoinedRoomNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _memberLeftRoom: ) name:MVChatConnectionUserLeftRoomNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _memberNicknameChanged: ) name:MVChatConnectionUserNicknameChangedNotification object:nil];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _memberOpped: ) name:MVChatConnectionUserOppedInRoomNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _memberDeopped: ) name:MVChatConnectionUserDeoppedInRoomNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _memberVoiced: ) name:MVChatConnectionUserVoicedInRoomNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _memberDevoiced: ) name:MVChatConnectionUserDevoicedInRoomNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _memberKicked: ) name:MVChatConnectionUserKickedFromRoomNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _kickedFromRoom: ) name:MVChatConnectionKickedFromRoomNotification object:nil];

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
	NSSet *ret = [NSSet setWithSet:_chatWindows];
	return [[ret retain] autorelease];
}

- (JVChatWindowController *) newChatWindowController {
	JVChatWindowController *windowController = [[[JVChatWindowController alloc] initWithWindowNibName:nil] autorelease];
	[self _addWindowController:windowController];
	return [[windowController retain] autorelease];
}

- (void) disposeChatWindowController:(JVChatWindowController *) controller {
	NSParameterAssert( controller != nil );
//	NSAssert1( [_chatWindows containsObject:controller], @"%@ is not a member of chat controller.", controller );
	NSLog( @"disposeChatWindowController %d", [controller retainCount] );
	[_chatControllers minusSet:[NSSet setWithArray:[controller allChatViewControllers]]];
	[_chatWindows removeObject:controller];
}

#pragma mark -

- (NSSet *) allChatViewControllers {
	NSSet *ret = [NSSet setWithSet:_chatControllers];
	return [[ret retain] autorelease];
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

- (id <JVChatViewController>) chatViewControllerForRoom:(NSString *) room withConnection:(MVChatConnection *) connection ifExists:(BOOL) exists {
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

- (id <JVChatViewController>) chatViewControllerForUser:(NSString *) user withConnection:(MVChatConnection *) connection ifExists:(BOOL) exists {
	id <JVChatViewController> ret = nil;
	NSEnumerator *enumerator = nil;

	NSParameterAssert( user != nil );
	NSParameterAssert( connection != nil );

	enumerator = [_chatControllers objectEnumerator];
	while( ( ret = [enumerator nextObject] ) )
		if( [ret isMemberOfClass:[JVDirectChat class]] && [ret connection] == connection && [[(JVDirectChat *)ret target] isEqualToString:user] )
			break;

	if( ! ret && ! exists ) {
		if( ( ret = [[[JVDirectChat alloc] initWithTarget:user forConnection:connection] autorelease] ) ) {
			[_chatControllers addObject:ret];
			[self _addViewControllerToPreferedWindowController:ret];
		}
	}

	return [[ret retain] autorelease];
}

- (id <JVChatViewController>) chatViewControllerForTranscript:(NSString *) filename {
	id <JVChatViewController> ret = nil;
	if( ( ret = [[[JVChatTranscript alloc] initWithTranscript:filename] autorelease] ) ) {
		[_chatControllers addObject:ret];
		[self _addViewControllerToPreferedWindowController:ret];
	}
	return [[ret retain] autorelease];
}

- (id <JVChatViewController>) chatConsoleForConnection:(MVChatConnection *) connection ifExists:(BOOL) exists {
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
	[[controller windowController] removeChatViewController:controller];
	[_chatControllers removeObject:controller];
}

#pragma mark -

- (void) detachView:(id) sender {
	id <JVChatViewController> view = [[[sender representedObject] retain] autorelease];
	JVChatWindowController *windowController = [self newChatWindowController];
	[[view windowController] removeChatViewController:view];
	[windowController addChatViewController:view];
	[windowController showChatViewController:view];
}
@end

#pragma mark -

@implementation JVChatController (JVChatControllerPrivate)
- (void) _joinedRoom:(NSNotification *) notification {
	[self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:NO];
}

- (void) _leftRoom:(NSNotification *) notification {
	id view = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	if( ! view ) return;
	[[JVChatController defaultManager] disposeViewController:view];
}

- (void) _memberJoinedRoom:(NSNotification *) notification {
	JVChatRoom *controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	[controller addMemberToChat:[[notification userInfo] objectForKey:@"who"] asPreviousMember:[[[notification userInfo] objectForKey:@"previousMember"] boolValue]];
}

- (void) _memberLeftRoom:(NSNotification *) notification {
	JVChatRoom *controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	[controller removeChatMember:[[notification userInfo] objectForKey:@"who"] withReason:[[notification userInfo] objectForKey:@"reason"]];
}

- (void) _memberNicknameChanged:(NSNotification *) notification {
	id controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	[(JVChatRoom *)controller changeChatMember:[[notification userInfo] objectForKey:@"oldNickname"] to:[[notification userInfo] objectForKey:@"newNickname"]];

	controller = [self chatViewControllerForUser:[[notification userInfo] objectForKey:@"oldNickname"] withConnection:[notification object] ifExists:YES];
	[controller setTarget:[[notification userInfo] objectForKey:@"newNickname"]];
}

- (void) _memberOpped:(NSNotification *) notification {
	JVChatRoom *controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	[controller promoteChatMember:[[notification userInfo] objectForKey:@"who"] by:[[notification userInfo] objectForKey:@"by"]];
}

- (void) _memberDeopped:(NSNotification *) notification {
	JVChatRoom *controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	[controller demoteChatMember:[[notification userInfo] objectForKey:@"who"] by:[[notification userInfo] objectForKey:@"by"]];
}

- (void) _memberVoiced:(NSNotification *) notification {
	JVChatRoom *controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	[controller voiceChatMember:[[notification userInfo] objectForKey:@"who"] by:[[notification userInfo] objectForKey:@"by"]];
}

- (void) _memberDevoiced:(NSNotification *) notification {
	JVChatRoom *controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	[controller devoiceChatMember:[[notification userInfo] objectForKey:@"who"] by:[[notification userInfo] objectForKey:@"by"]];
}

- (void) _memberKicked:(NSNotification *) notification {
	JVChatRoom *controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	[controller chatMember:[[notification userInfo] objectForKey:@"who"] kickedBy:[[notification userInfo] objectForKey:@"by"] forReason:[[notification userInfo] objectForKey:@"reason"]];
}

- (void) _kickedFromRoom:(NSNotification *) notification {
	JVChatRoom *controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	[controller kickedFromChatBy:[[notification userInfo] objectForKey:@"by"] forReason:[[notification userInfo] objectForKey:@"reason"]];
}

- (void) _gotPrivateMessage:(NSNotification *) notification {
	JVChatRoom *controller = [self chatViewControllerForUser:[[notification userInfo] objectForKey:@"from"] withConnection:[notification object] ifExists:NO];
	[controller addMessageToDisplay:[[notification userInfo] objectForKey:@"message"] fromUser:[[notification userInfo] objectForKey:@"from"] asAction:[[[notification userInfo] objectForKey:@"action"] boolValue]];
}

- (void) _gotRoomMessage:(NSNotification *) notification {
	JVChatRoom *controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	[controller addMessageToDisplay:[[notification userInfo] objectForKey:@"message"] fromUser:[[notification userInfo] objectForKey:@"from"] asAction:[[[notification userInfo] objectForKey:@"action"] boolValue]];
}

- (void) _roomTopicChanged:(NSNotification *) notification {
	JVChatRoom *controller = [self chatViewControllerForRoom:[[notification userInfo] objectForKey:@"room"] withConnection:[notification object] ifExists:YES];
	[controller changeTopic:[[notification userInfo] objectForKey:@"topic"] by:[[notification userInfo] objectForKey:@"author"]];
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
		windowController = [self newChatWindowController];
		break;
	case 1:
		enumerator = [_chatWindows objectEnumerator];
		while( ( windowController = [enumerator nextObject] ) )
			if( [[windowController window] isMainWindow] || ! [[NSApplication sharedApplication] isActive] )
				break;
		if( ! windowController ) windowController = [_chatWindows anyObject];
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
		} else windowController = [[[self chatViewControllersOfClass:modeClass] anyObject] windowController];
		break;
	}

	if( ! windowController ) windowController = [self newChatWindowController];

	[windowController addChatViewController:controller];
	[windowController showChatViewController:controller];
}
@end