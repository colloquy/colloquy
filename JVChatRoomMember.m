#import <Cocoa/Cocoa.h>
#import <AddressBook/AddressBook.h>
#import <ChatCore/MVChatConnection.h>

#import "JVChatRoom.h"
#import "JVChatRoomMember.h"
#import "JVChatController.h"
#import "MVBuddyListController.h"
#import "JVBuddy.h"

@interface JVChatRoomMember (JVChatRoomMemberPrivate)
- (NSString *) _selfStoredNickname;
- (NSString *) _selfCompositeName;
@end

#pragma mark -

@implementation JVChatRoomMember
- (id) initWithRoom:(JVChatRoom *) room andNickname:(NSString *) name {
	if( ( self = [self init] ) ) {
		_parent = room;
		_nickname = [name copy];
		_buddy = [[[MVBuddyListController sharedBuddyList] buddyForNickname:_nickname onServer:[[self connection] server]] retain];
	}
	return self;
}

- (id) init {
	if( ( self = [super init] ) ) {
		_parent = nil;
		_nickname = nil;
		_buddy = nil;
		_operator = NO;
		_voice = NO;
	}

	return self;
}

- (void) dealloc {
	[_nickname release];
	[_buddy release];

	_parent = nil;
	_nickname = nil;
	_buddy = nil;

	[super dealloc];
}

#pragma mark -

- (NSComparisonResult) compare:(JVChatRoomMember *) member {
	return [[self title] caseInsensitiveCompare:[member title]];
}

- (NSComparisonResult) compareUsingStatus:(JVChatRoomMember *) member {
	NSComparisonResult retVal;

	if( _operator && ! [member operator] ) {
		retVal = NSOrderedAscending;
	} else if ( ! _operator && [member operator] ) {
		retVal = NSOrderedDescending;
	} else if ( _voice && ! [member voice] && ! [member operator] ) {
		retVal = NSOrderedAscending;
	} else if ( ! _voice && [member voice] ) {
		retVal = NSOrderedDescending;
	} else {
		// retVal = [self compareUsingBuddyStatus:member];
		retVal = [[self title] caseInsensitiveCompare:[member title]];
	}

	return retVal;
}

- (NSComparisonResult) compareUsingBuddyStatus:(JVChatRoomMember *) member {
	NSComparisonResult retVal;

	if( ( _buddy && [member buddy]) || ( ! _buddy && ! [member buddy]) ) {
		if ( _buddy && [member buddy] ) {
			// if both are buddies, sort by availability
			retVal = [_buddy availabilityCompare:[member buddy]];
		} else {
			retVal = [[self title] caseInsensitiveCompare:[member title]]; // maybe an alpha sort here
		}
	} else if ( _buddy ) {
		// we have a buddy but since the first test failed, member does not
		// so of course the buddy is greater :)
		retVal = NSOrderedAscending;
	} else {
		// member is a buddy
		retVal = NSOrderedDescending;
	}

	return retVal;
}

#pragma mark -

- (BOOL) isEnabled {
	return [_parent isEnabled];
}

- (NSString *) title {
	if( [self isLocalUser] ) {
		if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatSelfNameStyle"] == (int)JVBuddyFullName )
			return [self _selfCompositeName];
		else if( [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatSelfNameStyle"] == (int)JVBuddyGivenNickname )
			return [self _selfStoredNickname];
	} else if( _buddy && [_buddy preferredNameWillReturn] != JVBuddyActiveNickname )
		return [_buddy preferredName];
	return [[_nickname retain] autorelease];
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

	if( ! [self isLocalUser] ) {
		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Send Message", "send message contextual menu") action:@selector( startChat: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];
	
		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Send File...", "send file contextual menu") action:@selector( sendFile: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];
	}

	if( ( [self isLocalUser] && _operator ) || [[_parent chatRoomMemberWithName:[[_parent connection] nickname]] operator] ) {
		[menu addItem:[NSMenuItem separatorItem]];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Kick From Room", "kick from room contextual menu - admin only" ) action:@selector( kick: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];

		[menu addItem:[NSMenuItem separatorItem]];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Make Operator", "make operator contextual menu - admin only" ) action:@selector( toggleOperatorStatus: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Grant Voice", "grant voice contextual menu - admin only" ) action:@selector( toggleVoiceStatus: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];
	}

	return [[menu retain] autorelease];
}

- (NSImage *) icon {
	return ( _operator ? [NSImage imageNamed:@"op"] : ( _voice ? [NSImage imageNamed:@"voice"] : [NSImage imageNamed:@"person"] ) );
}

- (NSImage *) statusImage {
	if( _buddy ) switch( [_buddy status] ) {
		case JVBuddyAwayStatus: return [NSImage imageNamed:@"statusAway"];
		case JVBuddyIdleStatus: return [NSImage imageNamed:@"statusIdle"];
		case JVBuddyAvailableStatus: return [NSImage imageNamed:@"statusAvailable"];
		case JVBuddyOfflineStatus:
		default: return nil;
	}
	return nil;
}

- (id <JVChatListItem>) parent {
	return _parent;
}

#pragma mark -

- (NSString *) nickname {
	return [[_nickname retain] autorelease];
}

- (JVBuddy *) buddy {
	return [[_buddy retain] autorelease];
}

#pragma mark -

- (BOOL) voice {
	return _voice;
}

- (BOOL) operator {
	return _operator;
}

- (BOOL) isLocalUser {
	return [_nickname isEqualToString:[[_parent connection] nickname]];
}

#pragma mark -

- (MVChatConnection *) connection {
	return [[[_parent connection] retain] autorelease];
}

#pragma mark -

- (BOOL) acceptsDraggedFileOfType:(NSString *) type {
	return YES;
}

- (void) handleDraggedFile:(NSString *) path {
	[[self connection] sendFile:path toUser:_nickname];
}

#pragma mark -

- (BOOL) validateMenuItem:(NSMenuItem *) menuItem {
	if( [menuItem action] == @selector( toggleVoiceStatus: ) ) {
		if( _voice ) {
			[menuItem setTitle:NSLocalizedString( @"Remove Voice", "remove voice contextual menu - admin only" )];
		} else {
			[menuItem setTitle:NSLocalizedString( @"Grant Voice", "grant voice contextual menu - admin only" )];
			if( _operator || ! [[self connection] isConnected] ) return NO;
		}
	} else if( [menuItem action] == @selector( toggleOperatorStatus: ) ) {
		if( _operator ) {
			[menuItem setTitle:NSLocalizedString( @"Demote Operator", "demote operator contextual menu - admin only" )];
		} else {
			[menuItem setTitle:NSLocalizedString( @"Make Operator", "make operator contextual menu - admin only" )];
		}
	}
	if( ! [[self connection] isConnected] ) return NO;
	return YES;
}

#pragma mark -

- (IBAction) doubleClicked:(id) sender {
	[self startChat:sender];
}

- (IBAction) startChat:(id) sender {
	if( [self isLocalUser] ) return;
	[[JVChatController defaultManager] chatViewControllerForUser:_nickname withConnection:[_parent connection] ifExists:NO];
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
			[[_parent connection] sendFile:path toUser:_nickname];
	}
}

#pragma mark -

- (IBAction) toggleOperatorStatus:(id) sender {
	if( _operator ) [[_parent connection] demoteMember:_nickname inRoom:[_parent target]];
	else [[_parent connection] promoteMember:_nickname inRoom:[_parent target]];
}

- (IBAction) toggleVoiceStatus:(id) sender {
	if( _voice ) [[_parent connection] devoiceMember:_nickname inRoom:[_parent target]];
	else [[_parent connection] voiceMember:_nickname inRoom:[_parent target]];
}

- (IBAction) kick:(id) sender {
	[[_parent connection] kickMember:_nickname inRoom:[_parent target] forReason:@""];
}
@end

#pragma mark -

@implementation JVChatRoomMember (JVChatMemberPrivate)
- (void) _setNickname:(NSString *) name {
	[_nickname autorelease];
	_nickname = [name copy];
	[_buddy autorelease];
	_buddy = [[[MVBuddyListController sharedBuddyList] buddyForNickname:_nickname onServer:[[self connection] server]] retain];
}

- (void) _setVoice:(BOOL) voice {
	_voice = voice;
}

- (void) _setOperator:(BOOL) operator {
	_operator = operator;
}

- (NSString *) _selfCompositeName {
	ABPerson *_person = [[ABAddressBook sharedAddressBook] me];
	NSString *firstName = [_person valueForProperty:kABFirstNameProperty];
	NSString *lastName = [_person valueForProperty:kABLastNameProperty];

	if( ! firstName && lastName ) return lastName;
	else if( firstName && ! lastName ) return firstName;
	else if( firstName && lastName ) {
		switch( [[ABAddressBook sharedAddressBook] defaultNameOrdering] ) {
			default:
			case kABFirstNameFirst:
				return [NSString stringWithFormat:@"%@ %@", firstName, lastName];
			case kABLastNameFirst:
				return [NSString stringWithFormat:@"%@ %@", lastName, firstName];
		}
	}

	firstName = [_person valueForProperty:kABNicknameProperty];
	if( firstName ) return firstName;

	return [[_parent connection] nickname];
}

- (NSString *) _selfStoredNickname {
	NSString *nickname = [[[ABAddressBook sharedAddressBook] me] valueForProperty:kABNicknameProperty];
	if( nickname ) return nickname;
	return [[_parent connection] nickname];
}
@end

#pragma mark -

@implementation JVChatRoomMember (JVChatRoomMemberScripting)
- (NSNumber *) uniqueIdentifier {
	return [NSNumber numberWithUnsignedInt:(unsigned long) self];
}

#pragma mark -

- (void) voiceScriptCommand:(NSScriptCommand *) command {
	if( ! _voice ) [self toggleVoiceStatus:nil];
}

- (void) devoiceScriptCommand:(NSScriptCommand *) command {
	if( _voice ) [self toggleVoiceStatus:nil];
}

- (void) promoteScriptCommand:(NSScriptCommand *) command {
	if( ! _operator ) [self toggleOperatorStatus:nil];
}

- (void) demoteScriptCommand:(NSScriptCommand *) command {
	if( _operator ) [self toggleOperatorStatus:nil];
}
@end