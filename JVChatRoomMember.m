#import <Cocoa/Cocoa.h>
#import <ChatCore/MVChatConnection.h>
#import "JVChatRoom.h"
#import "JVChatRoomMember.h"
#import "JVChatController.h"

@implementation JVChatRoomMember
- (id) init {
	self = [super init];
	_parent = nil;
	_memberName = nil;
	_operator = NO;
	_voice = NO;
	return self;
}

- (NSString *) title {
	return [[_memberName retain] autorelease];
}

- (NSString *) information {
	return nil;
}

- (int) numberOfChildren {
	return 0;
}

- (id) childAtIndex:(int) index {
	return nil;
}

- (NSMenu *) menu {
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *item = nil;

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Get Info", "get info contextual menu item title" ) action:@selector( getInfo: ) keyEquivalent:@""] autorelease];
	[item setTarget:[_parent windowController]];
	[menu addItem:item];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Send Message", "send message contextual menu") action:@selector( startChat: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Send File...", "send file contextual menu") action:@selector( sendFile: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	if( [(JVChatRoom *)_parent doesMemberHaveOperatorStatus:[[(JVChatRoom *)_parent connection] nickname]] ) {
		[menu addItem:[NSMenuItem separatorItem]];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Kick From Room", "kick from room contextual menu - admin only" ) action:@selector( kick: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];

		[menu addItem:[NSMenuItem separatorItem]];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Make Operator", "make operator contextual menu - admin only" ) action:@selector( promote: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Grant Voice", "grant voice contextual menu - admin only" ) action:@selector( voice: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];
	}

	return [[menu retain] autorelease];
}

- (NSImage *) icon {
	return ( _operator ? [NSImage imageNamed:@"op"] : ( _voice ? [NSImage imageNamed:@"voice"] : [NSImage imageNamed:@"person"] ) );
}

- (NSImage *) statusImage {
	return nil;
}

- (void) setParent:(id <JVChatListItem>) parent {
	if( ! [parent isMemberOfClass:[JVChatRoom class]] ) return;
	_parent = (JVChatRoom *)parent;
}

- (id <JVChatListItem>) parent {
	return _parent;
}

- (void) setMemberName:(NSString *) name {
	[_memberName autorelease];
	_memberName = [name copy];
}

- (NSString *) memberName {
	return [[_memberName retain] autorelease];
}

- (void) setVoice:(BOOL) voice {
	_voice = voice;
}

- (void) setOperator:(BOOL) operator {
	_operator = operator;
}

#pragma mark -

- (BOOL) validateMenuItem:(id <NSMenuItem>) menuItem {
	if( [menuItem action] == @selector( voice: ) ) {
		if( [_parent doesMemberHaveVoiceStatus:_memberName] ) {
			[menuItem setTitle:NSLocalizedString( @"Remove Voice", "remove voice contextual menu - admin only" )];
		} else {
			[menuItem setTitle:NSLocalizedString( @"Grant Voice", "grant voice contextual menu - admin only" )];
			if( [_parent doesMemberHaveOperatorStatus:_memberName] ) return NO;
		}
	} else if( [menuItem action] == @selector( promote: ) ) {
		if( [_parent doesMemberHaveOperatorStatus:_memberName] ) {
			[menuItem setTitle:NSLocalizedString( @"Demote Operator", "demote operator contextual menu - admin only" )];
		} else {
			[menuItem setTitle:NSLocalizedString( @"Make Operator", "make operator contextual menu - admin only" )];
		}
	}
	return YES;
}

- (IBAction) startChat:(id) sender {
	[[JVChatController defaultManager] chatViewControllerForUser:_memberName withConnection:[_parent connection] ifExists:NO];
}

- (IBAction) sendFile:(id) sender {
	NSString *path = nil;
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setResolvesAliases:YES];
	[panel setCanChooseFiles:YES];
	[panel setCanChooseDirectories:NO];
	[panel setAllowsMultipleSelection:YES];
	if( [panel runModalForTypes:nil] == NSOKButton ) {
		NSEnumerator *enumerator = [[panel filenames] objectEnumerator];
		while( ( path = [enumerator nextObject] ) )
			[[_parent connection] sendFileToUser:_memberName withFilePath:path];
	}
}

- (IBAction) promote:(id) sender {
	if( _operator ) [[_parent connection] demoteMember:_memberName inRoom:[_parent target]];
	else [[_parent connection] promoteMember:_memberName inRoom:[_parent target]];
}

- (IBAction) voice:(id) sender {
	if( _voice ) [[_parent connection] devoiceMember:_memberName inRoom:[_parent target]];
	else [[_parent connection] voiceMember:_memberName inRoom:[_parent target]];
}

- (IBAction) kick:(id) sender {
	[[_parent connection] kickMember:_memberName inRoom:[_parent target] forReason:@""];
}
@end