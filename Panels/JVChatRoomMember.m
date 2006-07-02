#import "JVChatRoomPanel.h"
#import "JVChatRoomMember.h"
#import "JVChatController.h"
#import "MVBuddyListController.h"
#import "MVFileTransferController.h"
#import "JVBuddy.h"
#import "JVChatMemberInspector.h"
#import "MVConnectionsController.h"

@interface JVChatRoomMember (JVChatMemberPrivate)
- (NSString *) _selfStoredNickname;
- (NSString *) _selfCompositeName;
- (KAIgnoreRule *) _tempIgnoreRule;
@end

#pragma mark -

@implementation JVChatRoomMember
+ (void) initialize {
	[super initialize];
	static BOOL tooLate = NO;
	if( ! tooLate ) {
		[[NSScriptCoercionHandler sharedCoercionHandler] registerCoercer:[self class] selector:@selector( coerceChatRoomMember:toString: ) toConvertFromClass:[JVChatRoomMember class] toClass:[NSString class]];
		tooLate = YES;
	}
}

+ (id) coerceChatRoomMember:(id) value toString:(Class) class {
	return [value nickname];
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_parent = nil;
		_user = nil;
		_nibLoaded = NO;
	}

	return self;
}

- (id) initWithRoom:(JVChatRoomPanel *) room andUser:(MVChatUser *) user {
	if( ( self = [self init] ) ) {
		_parent = room;
		_user = [user retain];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _refreshIcon: ) name:MVChatUserInformationUpdatedNotification object:user];
	}
	return self;
}

- (id) initLocalMemberWithRoom:(JVChatRoomPanel *) room {
	return ( self = [self initWithRoom:room andUser:[[room connection] localUser]] );
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_user release];

	_parent = nil;
	_user = nil;

	[super dealloc];
}

#pragma mark -
#pragma mark Comparisons

- (NSComparisonResult) compare:(JVChatRoomMember *) member {
	return [[self title] caseInsensitiveCompare:[member title]];
}

- (NSComparisonResult) compareUsingStatus:(JVChatRoomMember *) member {
	NSComparisonResult retVal = NSOrderedSame;
	unsigned long myStatus = 0, yourStatus = 0;

	myStatus = ( [self serverOperator] ? 1 << 8 : [[[self room] target] modesForMemberUser:[self user]] & ~MVChatRoomMemberQuietedMode );
	yourStatus = ( [member serverOperator] ? 1 << 8 : [[[member room] target] modesForMemberUser:[member user]] & ~MVChatRoomMemberQuietedMode );

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

- (NSComparisonResult) compareUsingBuddyStatus:(JVChatRoomMember *) member {
	NSComparisonResult retVal;

	if( ( [self buddy] && [member buddy]) || ( ! [self buddy] && ! [member buddy]) ) {
		if( [self buddy] && [member buddy] ) {
			// if both are buddies, sort by availability
			retVal = [[self buddy] availabilityCompare:[member buddy]];
		} else {
			retVal = [[self title] caseInsensitiveCompare:[member title]]; // maybe an alpha sort here
		}
	} else if( [self buddy] ) {
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
#pragma mark Associations

- (JVChatRoomPanel *) room {
	return (JVChatRoomPanel *)[self parent];
}

- (MVChatConnection *) connection {
	return [[self user] connection];
}

- (MVChatUser *) user {
	return _user;
}

- (JVBuddy *) buddy {
	return [[MVBuddyListController sharedBuddyList] buddyForUser:[self user]];
}

#pragma mark -
#pragma mark User Info

- (NSString *) displayName {
	return [[self user] displayName];
}

- (NSString *) nickname {
	return [[self user] nickname];
}

- (NSString *) realName {
	return [[self user] realName];
}

- (NSString *) username {
	return [[self user] username];
}

- (NSString *) address {
	return [[self user] address];
}

- (NSString *) hostmask {
	if( ! [[[self user] username] length] || ! [[[self user] address] length] ) return nil;
	return [NSString stringWithFormat:@"%@@%@", [[self user] username], [[self user] address]];
}

#pragma mark -
#pragma mark User Status

- (BOOL) quieted {
	return ( [[[self room] target] modesForMemberUser:[self user]] & MVChatRoomMemberQuietedMode );
}

- (BOOL) voice {
	return ( [[[self room] target] modesForMemberUser:[self user]] & MVChatRoomMemberVoicedMode );
}

- (BOOL) operator {
	return ( [[[self room] target] modesForMemberUser:[self user]] & MVChatRoomMemberOperatorMode );
}

- (BOOL) halfOperator {
	return ( [[[self room] target] modesForMemberUser:[self user]] & MVChatRoomMemberHalfOperatorMode );
}

- (BOOL) roomAdministrator {
	return ( [[[self room] target] modesForMemberUser:[self user]] & MVChatRoomMemberAdministratorMode );
}

- (BOOL) roomFounder {
	return ( [[[self room] target] modesForMemberUser:[self user]] & MVChatRoomMemberFounderMode );
}

- (BOOL) serverOperator {
	return [[self user] isServerOperator];
}

- (BOOL) isLocalUser {
	return [[self user] isLocalUser];
}

- (NSString *) description {
	return [self nickname];
}

- (NSString *) xmlDescription {
	return [self xmlDescriptionWithTagName:@"member"];
}

- (NSString *) xmlDescriptionWithTagName:(NSString *) tag {
	NSParameterAssert( [tag length] != 0 );

	// Full format will look like:
	// <member self="yes" nickname="..." hostmask="..." identifier="..." class="..." buddy="...">...</member>

	NSMutableString *ret = [NSMutableString string];
	[ret appendFormat:@"<%@", tag];

	if( [self isLocalUser] ) [ret appendString:@" self=\"yes\""];

	if( ! [[self displayName] isEqualToString:[self nickname]] )
		[ret appendFormat:@" nickname=\"%@\"", [[self nickname] stringByEncodingXMLSpecialCharactersAsEntities]];

	id hostmask = [self hostmask];
	if( hostmask ) [ret appendFormat:@" hostmask=\"%@\"", [hostmask stringByEncodingXMLSpecialCharactersAsEntities]];

	id uniqueId = [[self user] uniqueIdentifier];
	if( ! [uniqueId isEqual:[self nickname]] ) {
		if( [uniqueId isKindOfClass:[NSData class]] ) uniqueId = [uniqueId base64Encoding];
		else if( [uniqueId isKindOfClass:[NSString class]] ) uniqueId = [uniqueId stringByEncodingXMLSpecialCharactersAsEntities];
		[ret appendFormat:@" identifier=\"%@\"", uniqueId];
	}

	NSString *class = nil;
	if( [self serverOperator] ) class = @"server operator";
	else if( [self roomFounder] ) class = @"founder";
	else if( [self roomAdministrator] ) class = @"administrator";
	else if( [self operator] ) class = @"operator";
	else if( [self halfOperator] ) class = @"half operator";
	else if( [self voice] ) class = @"voice";

	if( class ) [ret appendFormat:@" class=\"%@\"", class];

	if( [self buddy] && ! [self isLocalUser] )
		[ret appendFormat:@" buddy=\"%@\"", [[[self buddy] uniqueIdentifier] stringByEncodingXMLSpecialCharactersAsEntities]];

	[ret appendFormat:@">%@</%@>", [[self displayName] stringByEncodingXMLSpecialCharactersAsEntities], tag];

	[ret stripIllegalXMLCharacters];
	return [NSString stringWithString:ret];
}

#pragma mark -
#pragma mark List Item Protocol Support

- (id <JVChatListItem>) parent {
	return _parent;
}

- (NSImage *) icon {
	unsigned long modes = [[[self room] target] modesForMemberUser:[self user]];
	NSString *iconName = @"person";

	if( [[self user] isServerOperator] ) iconName = @"admin";
	else if( modes & MVChatRoomMemberFounderMode ) iconName = @"founder";
	else if( modes & MVChatRoomMemberAdministratorMode ) iconName = @"super-op";
	else if( modes & MVChatRoomMemberOperatorMode ) iconName = @"op";
	else if( modes & MVChatRoomMemberHalfOperatorMode ) iconName = @"half-op";
	else if( modes & MVChatRoomMemberVoicedMode ) iconName = @"voice";

//	if( [[self user] status] == MVChatUserAwayStatus || [[self user] idleTime] > 600. )
//		iconName = [iconName stringByAppendingString:@"-idle"];

	return [NSImage imageNamed:iconName];
}

- (NSImage *) statusImage {
	if( [self buddy] ) switch( [[self buddy] status] ) {
		case MVChatUserAwayStatus: return [NSImage imageNamed:@"statusAway"];
		case MVChatUserAvailableStatus:
			if( [[self buddy] idleTime] >= 600. ) return [NSImage imageNamed:@"statusIdle"];
			else return [NSImage imageNamed:@"statusAvailable"];
		case MVChatUserOfflineStatus:
		default: return nil;
	}

	return nil;
}

- (NSString *) title {
	if( [self isLocalUser] ) {
		JVBuddyName nameStyle = [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatSelfNameStyle"];
		if( nameStyle == JVBuddyFullName ) return [self _selfCompositeName];
		else if( nameStyle == JVBuddyGivenNickname ) return [self _selfStoredNickname];
	} else if( [self buddy] ) return [[self buddy] displayName];
	return [self nickname];
}

- (NSString *) information {
	return nil;
}

- (NSString *) toolTip {
	if( ! [[self address] length] || ! [[self username] length] ) {
		if( [[self realName] length] )
			return [NSString stringWithFormat:@"%@ (%@)", [self nickname], [self realName]];
		return [self nickname];
	}

	if( [[self realName] length] )
		return [NSString stringWithFormat:@"%@ (%@)\n%@@%@", [self nickname], [self realName], [self username], [self address]];
	return [NSString stringWithFormat:@"%@\n%@@%@", [self nickname], [self username], [self address]];
}

- (BOOL) isEnabled {
	return [[self room] isEnabled] && ! ( [[self user] status] == MVChatUserAwayStatus || [[self user] idleTime] > 600. );
}

#pragma mark -

- (BOOL) acceptsDraggedFileOfType:(NSString *) type {
	return YES;
}

- (void) handleDraggedFile:(NSString *) path {
	BOOL passive = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSendFilesPassively"];
	[[MVFileTransferController defaultController] addFileTransfer:[[self user] sendFile:path passively:passive]];
}

#pragma mark -

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

	if( ! [self buddy] ) {
		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Add To Buddy List", "add to buddy list contextual menu") action:@selector( addBuddy: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];
	}

	if( ! [self isLocalUser] ) {
		[menu addItem:[NSMenuItem separatorItem]];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Ignore", "ignore user contextual menu") action:@selector( toggleIgnore: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[menu addItem:item];
	}

	unsigned int localUserModes = ( [[self connection] localUser] ? [(MVChatRoom *)[[self room] target] modesForMemberUser:[[self connection] localUser]] : 0 );
	BOOL canEdit = ( localUserModes & MVChatRoomMemberOperatorMode );
	if( ! canEdit ) canEdit = ( localUserModes & MVChatRoomMemberHalfOperatorMode );
	if( ! canEdit ) canEdit = ( localUserModes & MVChatRoomMemberAdministratorMode );
	if( ! canEdit ) canEdit = ( localUserModes & MVChatRoomMemberFounderMode );
	if( ! canEdit ) canEdit = [[[self connection] localUser] isServerOperator];

	if( canEdit ) {
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

		if( [self address] ) {
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
			[item setTarget:self];
			[menu addItem:item];

			item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( [NSString stringWithUTF8String:"Kick & Ban From Room..."], "kickban from room (customized) contextual menu - admin only" ) action:@selector( customKickban: ) keyEquivalent:@""] autorelease];
			[item setKeyEquivalentModifierMask:NSAlternateKeyMask];
			if( [item respondsToSelector:@selector( setAlternate: )] )
				[item setAlternate:YES];
			[item setTarget:self];
			[menu addItem:item];
		}

		[menu addItem:[NSMenuItem separatorItem]];

		NSSet *features = [[self connection] supportedFeatures];

		if( [features containsObject:MVChatRoomMemberOperatorFeature] ) {
			// correct title is added later in validateMenuItem:
			item = [[[NSMenuItem alloc] initWithTitle:@"" action:@selector( toggleOperatorStatus: ) keyEquivalent:@""] autorelease];
			[item setTarget:self];
			[menu addItem:item];
		}

		if( [features containsObject:MVChatRoomMemberHalfOperatorFeature] ) {
			// correct title is added later in validateMenuItem:
			item = [[[NSMenuItem alloc] initWithTitle:@"" action:@selector( toggleHalfOperatorStatus: ) keyEquivalent:@""] autorelease];
			[item setTarget:self];
			[menu addItem:item];
		}

		if( [features containsObject:MVChatRoomMemberVoicedFeature] ) {
			// correct title is added later in validateMenuItem:
			item = [[[NSMenuItem alloc] initWithTitle:@"" action:@selector( toggleVoiceStatus: ) keyEquivalent:@""] autorelease];
			[item setTarget:self];
			[menu addItem:item];
		}

		if( [features containsObject:MVChatRoomMemberQuietedFeature] ) {
			// correct title is added later in validateMenuItem:
			item = [[[NSMenuItem alloc] initWithTitle:@"" action:@selector( toggleQuietedStatus: ) keyEquivalent:@""] autorelease];
			[item setTarget:self];
			[menu addItem:item];
		}
	}

	return menu;
}

- (BOOL) validateMenuItem:(NSMenuItem *) menuItem {
	if( ! [[self connection] isConnected] ) return NO;
	if( [menuItem action] == @selector( toggleVoiceStatus: ) ) {
		if( [self voice] ) {
			[menuItem setTitle:NSLocalizedString( @"Remove Voice", "remove voice contextual menu - admin only" )];
		} else {
			[menuItem setTitle:NSLocalizedString( @"Grant Voice", "grant voice contextual menu - admin only" )];
			if( [self operator] || ! [[self connection] isConnected] ) return NO;
		}
	} else if( [menuItem action] == @selector( toggleQuietedStatus: ) ) {
		if( [self quieted] ) {
			[menuItem setTitle:NSLocalizedString( @"Remove Quiet", "remove quiet contextual menu - admin only" )];
		} else {
			[menuItem setTitle:NSLocalizedString( @"Force Quiet", "force quiet contextual menu - admin only" )];
		}
	} else if( [menuItem action] == @selector( toggleOperatorStatus: ) ) {
		if( [self operator] ) {
			[menuItem setTitle:NSLocalizedString( @"Demote Operator", "demote operator contextual menu - admin only" )];
		} else {
			[menuItem setTitle:NSLocalizedString( @"Make Operator", "make operator contextual menu - admin only" )];
		}
	} else if( [menuItem action] == @selector( toggleHalfOperatorStatus: ) ) {
		if( [self halfOperator] ) {
			[menuItem setTitle:NSLocalizedString( @"Demote Half Operator", "demote half-operator contextual menu - admin only" )];
		} else {
			[menuItem setTitle:NSLocalizedString( @"Make Half Operator", "make half-operator contextual menu - admin only" )];
		}
	} else if( [menuItem action] == @selector( toggleIgnore: ) ) {
		KAIgnoreRule *rule = [self _tempIgnoreRule];
		if( rule ) [menuItem setState:NSOnState];
		else [menuItem setState:NSOffState];
	}
	return YES;
}

#pragma mark -
#pragma mark Scripting Support

- (NSNumber *) uniqueIdentifier {
	return [NSNumber numberWithUnsignedInt:(unsigned long) self];
}

- (NSArray *) children {
	return nil;
}

#pragma mark -
#pragma mark GUI Actions

- (IBAction) doubleClicked:(id) sender {
	[self startChat:sender];
}

- (IBAction) startChat:(id) sender {
	if( [self isLocalUser] ) return;
	[[JVChatController defaultController] chatViewControllerForUser:[self user] ifExists:NO];
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
			[[MVFileTransferController defaultController] addFileTransfer:[[self user] sendFile:path passively:passive]];
	}
}

- (IBAction) addBuddy:(id) sender {
	[[MVBuddyListController sharedBuddyList] showBuddyPickerSheet:self];
	[[MVBuddyListController sharedBuddyList] setNewBuddyNickname:[self nickname]];
	[[MVBuddyListController sharedBuddyList] setNewBuddyFullname:[self realName]];
	[[MVBuddyListController sharedBuddyList] setNewBuddyServer:[self connection]];
}

- (IBAction) toggleIgnore:(id) sender {
	NSMutableArray *rules = [[MVConnectionsController defaultController] ignoreRulesForConnection:[self connection]];
	KAIgnoreRule *rule = [self _tempIgnoreRule];
	if( rule ) [rules removeObjectIdenticalTo:rule];
	else [rules addObject:[KAIgnoreRule ruleForUser:[self nickname] message:nil inRooms:nil isPermanent:NO friendlyName:[NSString stringWithFormat:@"%@ %@", [self displayName], NSLocalizedString( @" (Temporary)", "temporary ignore title suffix" )]]];
}

#pragma mark -
#pragma mark Operator Actions

- (IBAction) toggleOperatorStatus:(id) sender {
	if( [self operator] ) [[[self room] target] removeMode:MVChatRoomMemberOperatorMode forMemberUser:[self user]];
	else [[[self room] target] setMode:MVChatRoomMemberOperatorMode forMemberUser:[self user]];
}

- (IBAction) toggleHalfOperatorStatus:(id) sender {
	if( [self halfOperator] ) [[[self room] target] removeMode:MVChatRoomMemberHalfOperatorMode forMemberUser:[self user]];
	else [[[self room] target] setMode:MVChatRoomMemberHalfOperatorMode forMemberUser:[self user]];
}

- (IBAction) toggleVoiceStatus:(id) sender {
	if( [self voice] ) [[[self room] target] removeMode:MVChatRoomMemberVoicedMode forMemberUser:[self user]];
	else [[[self room] target] setMode:MVChatRoomMemberVoicedMode forMemberUser:[self user]];
}

- (IBAction) toggleQuietedStatus:(id) sender {
	if( [self quieted] ) [[[self room] target] removeMode:MVChatRoomMemberQuietedMode forMemberUser:[self user]];
	else [[[self room] target] setMode:MVChatRoomMemberQuietedMode forMemberUser:[self user]];
}

#pragma mark -

- (IBAction) kick:(id) sender {
	[[[self room] target] kickOutMemberUser:[self user] forReason:nil];
}

- (IBAction) ban:(id) sender {
	MVChatUser *user = [MVChatUser wildcardUserWithNicknameMask:nil andHostMask:[NSString stringWithFormat:@"*@%@", [self address]]];
	[[[self room] target] addBanForUser:user];
}

- (IBAction) customKick:(id) sender {
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"TSCustomBan" owner:self];
	if( ! _nibLoaded ) { NSLog( @"Can't load TSCustomBan.nib" ); return; }

	[banTitle setStringValue:[NSString stringWithFormat:NSLocalizedString( @"Kick %@ from the %@ room.", "kick user from room" ), [self title], [[self room] title]]];
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

	[[NSApplication sharedApplication] beginSheet:banWindow modalForWindow:[[[self room] view] window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

- (IBAction) customBan:(id) sender {
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"TSCustomBan" owner:self];
	if( ! _nibLoaded ) { NSLog( @"Can't load TSCustomBan.nib" ); return; }

	[banTitle setStringValue:[NSString stringWithFormat:NSLocalizedString( @"Ban %@ from the %@ room.", "ban user from room label" ), [self title], [[self room] title]]];
	[firstTitle setStringValue:NSLocalizedString( @"With hostmask:", "ban hostmask label")];

	if( [self username] && [self address] )
		[firstField setStringValue:[NSString stringWithFormat:@"%@!%@@%@", [self nickname], [self username], [self address]]];
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

	[[NSApplication sharedApplication] beginSheet:banWindow modalForWindow:[[[self room] view] window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

- (IBAction) kickban:(id) sender {
	[self ban:nil];
	[self kick:nil];
}

- (IBAction) customKickban:(id) sender {
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"TSCustomBan" owner:self];
	if( ! _nibLoaded ) { NSLog(@"Can't load TSCustomBan.nib"); return; }

	[banTitle setStringValue:[NSString stringWithFormat:NSLocalizedString( @"Kick and ban %@ from the %@ room.", "kickban user from room" ), [self title], [[self room] title]]];
	[banTitle sizeToFit];

	[firstTitle setStringValue:NSLocalizedString( @"With hostmask:", "ban hostmask" )];
	[secondTitle setStringValue:NSLocalizedString( @"And reason:", "kick reason (secondary)" )];

	if( [self username] && [self address] )
		[firstField setStringValue:[NSString stringWithFormat:@"%@!%@@%@", [self nickname], [self username], [self address]]];
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

	[[NSApplication sharedApplication] beginSheet:banWindow modalForWindow:[[[self room] view] window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

- (IBAction) closeKickSheet:(id) sender {
	[[NSApplication sharedApplication] endSheet:banWindow];
	[banWindow orderOut:self];

	NSAttributedString *reason = [[[NSAttributedString alloc] initWithString:[firstField stringValue]] autorelease];
	[[[self room] target] kickOutMemberUser:[self user] forReason:reason];
}

- (IBAction) closeBanSheet:(id) sender {
	[[NSApplication sharedApplication] endSheet:banWindow];
	[banWindow orderOut:self];

	MVChatUser *user = [MVChatUser wildcardUserFromString:[firstField stringValue]];
	[[[self room] target] addBanForUser:user];
}

- (IBAction) closeKickbanSheet:(id) sender {
	[[NSApplication sharedApplication] endSheet:banWindow];
	[banWindow orderOut:self];

	MVChatUser *user = [MVChatUser wildcardUserFromString:[firstField stringValue]];
	[[[self room] target] addBanForUser:user];

	NSAttributedString *reason = [[[NSAttributedString alloc] initWithString:[secondField stringValue]] autorelease];
	[[[self room] target] kickOutMemberUser:[self user] forReason:reason];
}

- (IBAction) cancelSheet:(id) sender {
	[[NSApplication sharedApplication] endSheet:banWindow];
	[banWindow orderOut:self];
}

#pragma mark -

- (id) valueForUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The member id %@ of chat room panel id %@ doesn't have the \"%@\" property.", [self uniqueIdentifier], [[self room] uniqueIdentifier], key]];
		return nil;
	}

	return [super valueForUndefinedKey:key];
}

- (void) setValue:(id) value forUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The \"%@\" property of member id %@ of chat room panel id %@ is read only.", key, [self uniqueIdentifier], [[self room] uniqueIdentifier]]];
		return;
	}

	[super setValue:value forUndefinedKey:key];
}
@end

#pragma mark -

@implementation JVChatRoomMember (JVChatMemberPrivate)
- (KAIgnoreRule *) _tempIgnoreRule {
	NSString *ignoreSuffix = NSLocalizedString( @" (Temporary)", "temporary ignore title suffix" );
	NSMutableArray *rules = [[MVConnectionsController defaultController] ignoreRulesForConnection:[self connection]];
	NSEnumerator *enumerator = [rules objectEnumerator];
	KAIgnoreRule *rule = nil;

	while( ( rule = [enumerator nextObject] ) )
		if( ! [rule isPermanent] && [[rule friendlyName] hasSuffix:ignoreSuffix]
			&& [rule matchUser:[self user] message:nil inView:[self room]] != JVNotIgnored ) break;

	return rule;
}

- (void) _refreshIcon:(NSNotification *) notification {
	[[[self room] windowController] reloadListItem:self andChildren:NO];
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

	return [[self connection] nickname];
}

- (NSString *) _selfStoredNickname {
	NSString *nickname = [[[ABAddressBook sharedAddressBook] me] valueForProperty:kABNicknameProperty];
	if( nickname ) return nickname;
	return [[self connection] nickname];
}
@end