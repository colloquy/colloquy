#import <Cocoa/Cocoa.h>
#import "JVChatRoomMember.h"

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

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Get Info", "get info contextual menu item title" ) action:NULL keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Send Message", "send message contextual menu") action:@selector( startChatWithSelectedUser: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Send File...", "send file contextual menu") action:@selector( sendFileToSelectedUser: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

/*	if( [[memberList objectForKey:[[self connection] nickname]] objectForKey:@"op"] ) {
		[menu addItem:[NSMenuItem separatorItem]];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Kick From Room", "kick from room contextual menu - admin only" ) action:@selector( kickSelectedUser: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];

		[menu addItem:[NSMenuItem separatorItem]];

		if( [[memberList objectForKey:[sortedMembers objectAtIndex:[memberListTable selectedRow]]] objectForKey:@"op"] ) {
			item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Demote Operator", "demote operator contextual menu - admin only" ) action:@selector( promoteSelectedUser: ) keyEquivalent:@""] autorelease];
			[item setTarget:self];
			[menu addItem:item];
		} else {
			item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Make Operator", "make operator contextual menu - admin only" ) action:@selector( promoteSelectedUser: ) keyEquivalent:@""] autorelease];
			[item setTarget:self];
			[menu addItem:item];
		}

		if( [[memberList objectForKey:[sortedMembers objectAtIndex:[memberListTable selectedRow]]] objectForKey:@"voice"] ) {
			item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Remove Voice", "remove voice contextual menu - admin only" ) action:@selector( voiceSelectedUser: ) keyEquivalent:@""] autorelease];
			[item setTarget:self];
			[menu addItem:item];
		} else {
			item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Grant Voice", "grant voice contextual menu - admin only" ) action:@selector( voiceSelectedUser: ) keyEquivalent:@""] autorelease];
			[item setTarget:self];
			[menu addItem:item];
		}
	}*/

	return [[menu retain] autorelease];
}

- (NSImage *) icon {
	return ( _operator ? [NSImage imageNamed:@"op"] : ( _voice ? [NSImage imageNamed:@"voice"] : [NSImage imageNamed:@"person"] ) );
}

- (void) setParent:(id <JVChatListItem>) parent {
	_parent = parent;
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
@end
