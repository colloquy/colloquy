#import <Cocoa/Cocoa.h>
#import <AddressBook/AddressBook.h>
#import <ChatCore/MVChatConnection.h>

#import "JVChatRoom.h"
#import "JVChatRoomMember.h"
#import "JVChatController.h"
#import "MVBuddyListController.h"
#import "MVFileTransferController.h"
#import "JVBuddy.h"
#import "JVChatMemberInspector.h"

@interface JVChatRoomMember (JVChatMemberPrivate)
- (NSString *) _selfStoredNickname;
- (NSString *) _selfCompositeName;
@end

#pragma mark -

@implementation JVChatRoomMember
- (id) initWithRoom:(JVChatRoom *) room andNickname:(NSString *) name {
	if( ( self = [self init] ) ) {
		_parent = room;
		_nickname = [[name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] retain];
		_buddy = [[[MVBuddyListController sharedBuddyList] buddyForNickname:_nickname onServer:[[self connection] server]] retain];
	}
	return self;
}

- (id) init {
	if( ( self = [super init] ) ) {
		_parent = nil;
		_nickname = nil;
		_realName = nil;
		_address = nil;
		_buddy = nil;
		_operator = NO;
		_halfOperator = NO;
		_serverOperator = NO;
		_voice = NO;
		_nibLoaded = NO;
	}

	return self;
}

- (void) dealloc {
	[_nickname release];
	[_realName release];
	[_address release];
	[_buddy release];

	_parent = nil;
	_nickname = nil;
	_realName = nil;
	_address = nil;
	_buddy = nil;

	[super dealloc];
}

#pragma mark -
#pragma mark Comparisons

- (NSComparisonResult) compare:(JVChatRoomMember *) member {
	return [[self title] caseInsensitiveCompare:[member title]];
}

- (NSComparisonResult) compareUsingStatus:(JVChatRoomMember *) member {
	NSComparisonResult retVal = NSOrderedSame;
	unsigned myStatus = 0, yourStatus = 0;

	myStatus = ( _serverOperator * 50 ) + ( _operator * 10 ) + ( _halfOperator * 5 ) + ( _voice * 1 );
	yourStatus = ( [member serverOperator] * 50 ) + ( [member operator] * 10 ) + ( [member halfOperator] * 5 ) + ( [member voice] * 1 );

	if( myStatus > yourStatus ) {
		retVal = NSOrderedAscending;
	} else if( yourStatus > myStatus ) {
		retVal = NSOrderedDescending;
	} else {
		// retVal = [self compareUsingBuddyStatus:member];
		retVal = [[self title] caseInsensitiveCompare:[member title]];
	}

	return retVal;
}

#pragma mark -
#pragma mark User Info

- (NSString *) nickname {
	return [[_nickname retain] autorelease];
}

- (NSString *) realName {
	return [[_realName retain] autorelease];
}

- (NSString *) address {
	return [[_address retain] autorelease];
}

- (NSImage *) icon {
	NSImage *icon = nil;
	if( _serverOperator ) icon = [NSImage imageNamed:@"admin"];
	else if( _operator ) icon = [NSImage imageNamed:@"op"];
	else if( _halfOperator ) icon = [NSImage imageNamed:@"half-op"];
	else if( _voice ) icon = [NSImage imageNamed:@"voice"];
	else icon = [NSImage imageNamed:@"person"];
	return icon;
}

- (JVBuddy *) buddy {
	return [[_buddy retain] autorelease];
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

- (BOOL) voice {
	return _voice;
}

- (BOOL) operator {
	return _operator;
}

- (BOOL) halfOperator {
	return _halfOperator;
}

- (BOOL) serverOperator {
	return _serverOperator;
}

- (BOOL) isLocalUser {
	return [_nickname isEqualToString:[[_parent connection] nickname]];
}

- (MVChatConnection *) connection {
	return [[[_parent connection] retain] autorelease];
}

- (NSComparisonResult) compareUsingBuddyStatus:(JVChatRoomMember *) member {
	NSComparisonResult retVal;

	if( ( _buddy && [member buddy]) || ( ! _buddy && ! [member buddy]) ) {
		if( _buddy && [member buddy] ) {
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
#pragma mark Outline View Support

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

- (NSString *) toolTip {
	if( ! [self address] ) return nil;
	return [NSString stringWithFormat:@"%@\n%@", [self title], [self address]];
}

- (id <JVChatListItem>) parent {
	return _parent;
}

- (BOOL) isEnabled {
	return [_parent isEnabled];
}

#pragma mark -
#pragma mark Drag & Drop Support
//not so much drop though

- (BOOL) acceptsDraggedFileOfType:(NSString *) type {
	return YES;
}

- (void) handleDraggedFile:(NSString *) path {
	BOOL passive = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSendFilesPassively"];
	[[MVFileTransferController defaultManager] addFileTransfer:[[self connection] sendFile:path toUser:_nickname passively:passive]];
}

#pragma mark -
#pragma mark Contextual Menu

- (IBAction) getInfo:(id) sender {
	[[JVInspectorController inspectorOfObject:self] show:sender];
}

- (NSMenu *) menu {
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *item = nil;

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Get Info", "get info contextual menu item title" ) action:@selector( getInfo: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	if( ! [self isLocalUser] ) {
		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Send Message", "send message contextual menu") action:@selector( startChat: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];
		
		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Send File...", "send file contextual menu") action:@selector( sendFile: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];
	}

	if ( _buddy == nil ) {
		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Add To Buddy List", "add to buddy list contextual menu") action:@selector( addBuddy: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];
	}

	if( ( [self isLocalUser] && _operator ) || [[_parent chatRoomMemberWithName:[[_parent connection] nickname]] operator] ) {
		[menu addItem:[NSMenuItem separatorItem]];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Kick From Room", "kick from room contextual menu - admin only" ) action:@selector( kick: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( [NSString stringWithUTF8String:"Kick From Room..."], "kick from room (customized) contextual menu - admin only" ) action:@selector( customKick: ) keyEquivalent:@""] autorelease];
		[item setKeyEquivalentModifierMask:NSAlternateKeyMask];
		if( [item respondsToSelector:@selector( setAlternate: )] )
			[item setAlternate:YES];
		[item setTarget:self];
		[menu addItem:item];

		if ( _address ) {
			item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Ban From Room", "ban from room contextual menu - admin only" ) action:@selector( ban: ) keyEquivalent:@""] autorelease];
			[item setTarget:self];
			[menu addItem:item];

			item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( [NSString stringWithUTF8String:"Ban From Room..."], "ban from room (customized) contextual menu - admin only" ) action:@selector( customBan: ) keyEquivalent:@""] autorelease];
			[item setKeyEquivalentModifierMask:NSAlternateKeyMask];
			if( [item respondsToSelector:@selector( setAlternate: )] )
				[item setAlternate:YES];
			[item setTarget:self];
			[menu addItem:item];

			item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Kick & Ban From Room", "kickban from room contextual menu - admin only" ) action:@selector( kickban: ) keyEquivalent:@""] autorelease];
			[item setKeyEquivalentModifierMask:NSShiftKeyMask];
			if( [item respondsToSelector:@selector( setAlternate: )] )
				[item setAlternate:YES];
			[item setTarget:self];
			[menu addItem:item];

			item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( [NSString stringWithUTF8String:"Kick & Ban From Room..."], "kickban from room (customized) contextual menu - admin only" ) action:@selector( customKickban: ) keyEquivalent:@""] autorelease];
			[item setKeyEquivalentModifierMask:( NSShiftKeyMask | NSAlternateKeyMask )];
			if( [item respondsToSelector:@selector( setAlternate: )] )
				[item setAlternate:YES];
			[item setTarget:self];
			[menu addItem:item];
		}

		[menu addItem:[NSMenuItem separatorItem]];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Make Operator", "make operator contextual menu - admin only" ) action:@selector( toggleOperatorStatus: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Make Half Operator", "make half-operator contextual menu - admin only" ) action:@selector( toggleHalfOperatorStatus: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Grant Voice", "grant voice contextual menu - admin only" ) action:@selector( toggleVoiceStatus: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];
	}

	return [[menu retain] autorelease];
}

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
	} else if( [menuItem action] == @selector( toggleHalfOperatorStatus: ) ) {
		if( _halfOperator ) {
			[menuItem setTitle:NSLocalizedString( @"Demote Half Operator", "demote half-operator contextual menu - admin only" )];
		} else {
			[menuItem setTitle:NSLocalizedString( @"Make Half Operator", "make half-operator contextual menu - admin only" )];
		}
	}
	if( ! [[self connection] isConnected] ) return NO;
	return YES;
}

#pragma mark -
#pragma mark GUI Actions

- (IBAction) doubleClicked:(id) sender {
	[self startChat:sender];
}

- (IBAction) startChat:(id) sender {
	if( [self isLocalUser] ) return;
	[[JVChatController defaultManager] chatViewControllerForUser:_nickname withConnection:[_parent connection] ifExists:NO];
}

- (IBAction) sendFile:(id) sender {
	BOOL passive = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSendFilesPassively"];
	NSString *path = nil;
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setResolvesAliases:YES];
	[panel setCanChooseFiles:YES];
	[panel setCanChooseDirectories:NO];
	[panel setAllowsMultipleSelection:YES];

	NSView *view = [[[NSView alloc] initWithFrame:NSMakeRect( 0., 0., 200., 28. )] autorelease];
	[view setAutoresizingMask:( NSViewWidthSizable | NSViewMaxXMargin )];

	NSButton *passiveButton = [[[NSButton alloc] initWithFrame:NSMakeRect( 0., 6., 200., 18. )] autorelease];
	[[passiveButton cell] setButtonType:NSSwitchButton];
	[passiveButton setState:passive];
	[passiveButton setTitle:NSLocalizedString( @"Send File Passively", "send files passively file send open dialog button" )];
	[passiveButton sizeToFit];

	NSRect frame = [view frame];
	frame.size.width = NSWidth( [passiveButton frame] );

	[view setFrame:frame];
	[view addSubview:passiveButton];

	[panel setAccessoryView:view];

	if( [panel runModalForTypes:nil] == NSOKButton ) {
		NSEnumerator *enumerator = [[panel filenames] objectEnumerator];
		passive = [passiveButton state];
		while( ( path = [enumerator nextObject] ) )
			[[MVFileTransferController defaultManager] addFileTransfer:[[_parent connection] sendFile:path toUser:_nickname passively:passive]];
	}
}

- (IBAction) addBuddy:(id) sender {
	[[MVBuddyListController sharedBuddyList] showBuddyPickerSheet:self];
	[[MVBuddyListController sharedBuddyList] setNewBuddyNickname:[self nickname]];
	[[MVBuddyListController sharedBuddyList] setNewBuddyFullname:[self realName]];
	[[MVBuddyListController sharedBuddyList] setNewBuddyServer:[self connection]];
}

#pragma mark -
#pragma mark Operator commands/Modifiers

- (IBAction) toggleOperatorStatus:(id) sender {
	if( _operator ) [[_parent connection] demoteMember:_nickname inRoom:[_parent target]];
	else [[_parent connection] promoteMember:_nickname inRoom:[_parent target]];
}

- (IBAction) toggleHalfOperatorStatus:(id) sender {
	if( _halfOperator ) [[_parent connection] dehalfopMember:_nickname inRoom:[_parent target]];
	else [[_parent connection] halfopMember:_nickname inRoom:[_parent target]];
}

- (IBAction) toggleVoiceStatus:(id) sender {
	if( _voice ) [[_parent connection] devoiceMember:_nickname inRoom:[_parent target]];
	else [[_parent connection] voiceMember:_nickname inRoom:[_parent target]];
}

- (IBAction) kick:(id) sender {
	[[_parent connection] kickMember:_nickname inRoom:[_parent target] forReason:@""];
}

- (IBAction) ban:(id) sender {
	if( _address ) {
		// Address is in the form of user@hostmask, lets get rid of the user bit
		NSArray *parts = [_address componentsSeparatedByString:@"@"];
		if( [parts count] == 2 ) {
			NSString *hostmask = [parts objectAtIndex:1];
			[[_parent connection] banMember:[NSString stringWithFormat:@"*!*@%@", hostmask] inRoom:[_parent target]];
		}
	}
}

- (IBAction) customKick:(id) sender {
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"TSCustomBan" owner:self];
	if( ! _nibLoaded ) { NSLog( @"Can't load TSCustomBan.nib" ); return; }

	[banTitle setStringValue:[NSString stringWithFormat:NSLocalizedString( @"Kick %@ from the %@ room.", "kick user from room" ), [self title], [_parent title]]];
	[firstTitle setStringValue:NSLocalizedString( @"With reason:", "kick reason label" )];

	[firstField setStringValue:@""];
	[banWindow makeFirstResponder:firstField];

	if( [secondTitle respondsToSelector:@selector(setHidden:)] ) {
		[secondTitle setHidden:YES];
		[secondField setHidden:YES];
	} else {
		NSRect frame = [secondTitle frame];
		frame.origin.x = 0. - frame.size.width - 10.;
		[secondTitle setFrame:frame];
		frame = [secondField frame];
		frame.origin.x = 0. - frame.size.width - 10.;
		[secondField setFrame:frame];
	}

	NSRect frame = [banWindow frame];
	frame.size.height = ( frame.size.height - [firstField frame].origin.y ) + 60.;
	[banWindow setFrame:frame display:YES];

	[banButton setAction:@selector( closeKickSheet: )];
	[banButton setTitle:NSLocalizedString( @"Kick User", "kick user button" )];
	[banButton setTarget:self];

	[NSApp beginSheet:banWindow modalForWindow:[[_parent view] window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

- (IBAction) customBan:(id) sender {
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"TSCustomBan" owner:self];
	if( ! _nibLoaded ) { NSLog( @"Can't load TSCustomBan.nib" ); return; }

	[banTitle setStringValue:[NSString stringWithFormat:NSLocalizedString( @"Ban %@ from the %@ room.", "ban user from room label" ), [self title], [_parent title]]];
	[firstTitle setStringValue:NSLocalizedString( @"With hostmask:", "ban hostmask label")];

	if( _address) [firstField setStringValue:[NSString stringWithFormat:@"%@!%@", _nickname, _address]];
	else [firstField setStringValue:@""];

	[banWindow makeFirstResponder:firstField];

	if( [secondTitle respondsToSelector:@selector( setHidden: )] ) {
		[secondTitle setHidden:YES];
		[secondField setHidden:YES];
	} else {
		NSRect frame = [secondTitle frame];
		frame.origin.x = 0. - frame.size.width - 10.;
		[secondTitle setFrame:frame];
		frame = [secondField frame];
		frame.origin.x = 0. - frame.size.width - 10.;
		[secondField setFrame:frame];
	}

	NSRect frame = [banWindow frame];
	frame.size.height = ( frame.size.height - [firstField frame].origin.y ) + 60.;
	[banWindow setFrame:frame display:YES];

	[banButton setAction:@selector( closeBanSheet: )];
	[banButton setTitle:NSLocalizedString( @"Ban User", "ban user button" )];
	[banButton setTarget:self];

	[NSApp beginSheet:banWindow modalForWindow:[[_parent view] window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

- (IBAction) kickban:(id) sender {
	[self ban:nil];
	[self kick:nil];
}

- (IBAction) customKickban:(id) sender {
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"TSCustomBan" owner:self];
	if( ! _nibLoaded ) { NSLog(@"Can't load TSCustomBan.nib"); return; }

	[banTitle setStringValue:[NSString stringWithFormat:NSLocalizedString( @"Kick and ban %@ from the %@ room.", "kickban user from room" ), [self title], [_parent title]]];
	[banTitle sizeToFit];

	[firstTitle setStringValue:NSLocalizedString( @"With hostmask:", "ban hostmask" )];
	[secondTitle setStringValue:NSLocalizedString( @"And reason:", "kick reason (secondary)" )];

	if( _address ) [firstField setStringValue:[NSString stringWithFormat:@"%@!%@", _nickname, _address]];
	else [firstField setStringValue:@""];
	[secondField setStringValue:@""];

	[banWindow makeFirstResponder:firstField];

	if( [secondTitle respondsToSelector:@selector( setHidden: )] ) {
		[secondTitle setHidden:NO];
		[secondField setHidden:NO];
	} else {
		NSRect frame = [secondTitle frame];
		frame.origin.y = [firstField frame].origin.y - frame.size.height - 8;
		frame.origin.x = [firstField frame].origin.x;
		[secondTitle setFrame:frame];
		frame.size = [secondField frame].size;
		frame.origin.y = frame.origin.y - frame.size.height - 8;
		[secondField setFrame:frame];
	}

	NSRect frame = [banWindow frame];
	frame.size.height = ( frame.size.height - [secondField frame].origin.y ) + 60;
	[banWindow setFrame:frame display:YES];

	[banButton setAction:@selector( closeKickbanSheet: )];
	[banButton setTitle:NSLocalizedString( @"Kick & Ban User", "kick and ban user button" )];
	[banButton setTarget:self];

	[[NSApplication sharedApplication] beginSheet:banWindow modalForWindow:[[_parent view] window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

- (IBAction) closeKickSheet:(id) sender {
	NSString *reason = [firstField stringValue];
	[[NSApplication sharedApplication] endSheet:banWindow];
	[banWindow orderOut:self];

	[[_parent connection] kickMember:_nickname inRoom:[_parent target] forReason:reason];
}

- (IBAction) closeBanSheet:(id) sender {
	NSString *hostmask = [firstField stringValue];
	[NSApp endSheet:banWindow];
	[banWindow orderOut:self];

	[[_parent connection] banMember:hostmask inRoom:[_parent target]];
}

- (IBAction) closeKickbanSheet:(id) sender {
	NSString *hostmask = [firstField stringValue];
	NSString *reason = [secondField stringValue];
	[NSApp endSheet:banWindow];
	[banWindow orderOut:self];

	[[_parent connection] banMember:hostmask inRoom:[_parent target]];
	[[_parent connection] kickMember:_nickname inRoom:[_parent target] forReason:reason];
}

- (IBAction) cancelSheet:(id) sender {
	[NSApp endSheet:banWindow];
	[banWindow orderOut:self];
}
@end

#pragma mark -

@implementation JVChatRoomMember (JVChatRoomMemberObjectSpecifier)
- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[JVChatRoom class]];
	NSScriptObjectSpecifier *container = [_parent objectSpecifier];
	return [[[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"chatMembers" uniqueID:[self uniqueIdentifier]] autorelease];
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

- (void) _setAddress:(NSString *) address {
	[_address autorelease];
	_address = [address copy];
}

- (void) _setRealName:(NSString *) name {
	[_realName autorelease];
	_realName = [name copy];
}

- (void) _setVoice:(BOOL) voice {
	_voice = voice;
}

- (void) _setOperator:(BOOL) operator {
	_operator = operator;
}

- (void) _setHalfOperator:(BOOL) operator {
	_halfOperator = operator;
}

- (void) _setServerOperator:(BOOL) operator {
	_serverOperator = operator;
}

- (NSString *) _selfCompositeName {
	ABPerson *_person = [[ABAddressBook sharedAddressBook] me];
	NSString *firstName = [_person valueForProperty:kABFirstNameProperty];
	NSString *lastName = [_person valueForProperty:kABLastNameProperty];

	if( ! firstName && lastName ) return lastName;
	else if( firstName && ! lastName ) return firstName;
	else if( firstName && lastName ) {
		return [NSString stringWithFormat:@"%@ %@", firstName, lastName];
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