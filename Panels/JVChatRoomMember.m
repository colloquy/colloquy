#import "JVChatRoomPanel.h"
#import "JVChatRoomMember.h"
#import "JVChatController.h"
#import "NSImageAdditions.h"
#import "MVBuddyListController.h"
#import "MVFileTransferController.h"
#import "JVBuddy.h"
#import "JVChatUserInspector.h"
#import "MVConnectionsController.h"
#import "MVChatUserAdditions.h"

NS_ASSUME_NONNULL_BEGIN

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

- (instancetype) initWithRoom:(JVChatRoomPanel *) room andUser:(MVChatUser *) user {
	if( ( self = [super init] ) ) {
		_room = room; // prevent circular retain
		_user = user;

		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _refreshIcon: ) name:MVChatUserInformationUpdatedNotification object:user];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _refreshIcon: ) name:MVChatUserStatusChangedNotification object:user];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _refreshIcon: ) name:MVChatUserAwayStatusMessageChangedNotification object:user];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _refreshIcon: ) name:MVChatUserIdleTimeUpdatedNotification object:user];
	}

	return self;
}

- (instancetype) initLocalMemberWithRoom:(JVChatRoomPanel *) room {
	return [self initWithRoom:room andUser:[[room connection] localUser]];
}

- (void) dealloc {
	[self _detach];
}

#pragma mark -
#pragma mark Comparisons

- (NSComparisonResult) compare:(JVChatRoomMember *) member {
	return [[self title] caseInsensitiveCompare:[member title]];
}

- (NSComparisonResult) compareUsingStatus:(JVChatRoomMember *) member {
	NSUInteger myStatus = [[_room target] modesForMemberUser:_user];
	NSUInteger yourStatus = [[_room target] modesForMemberUser:member.user];

	if( myStatus > yourStatus )
		return NSOrderedAscending;
	if( yourStatus > myStatus )
		return NSOrderedDescending;
	return [[self title] caseInsensitiveCompare:[member title]];
}

- (NSComparisonResult) compareUsingBuddyStatus:(JVChatRoomMember *) member {
	NSComparisonResult retVal;

	JVBuddy *buddy1 = [self buddy];
	JVBuddy *buddy2 = [member buddy];

	if( ( buddy1 && buddy2) || ( ! buddy1 && ! buddy2) ) {
		if( buddy1 && buddy2 ) {
			// if both are buddies, sort by availability
			retVal = [buddy1 availabilityCompare:buddy2];
		} else {
			retVal = [[self title] caseInsensitiveCompare:[member title]]; // maybe an alpha sort here
		}
	} else if( buddy1 ) {
		// we have a buddy but since the first test failed, member does not
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
	return _room;
}

- (MVChatConnection *) connection {
	return [_user connection];
}

- (MVChatUser *) user {
	return _user;
}

- (nullable JVBuddy *) buddy {
	return [[MVBuddyListController sharedBuddyList] buddyForUser:_user];
}

#pragma mark -
#pragma mark User Info

- (NSString *) displayName {
	return [_user displayName];
}

- (NSString *) nickname {
	return [_user nickname];
}

- (NSString *) realName {
	return [_user realName];
}

- (NSString *) username {
	return [_user username];
}

- (NSString *) address {
	return [_user address];
}

- (nullable NSString *) hostmask {
	if( ! [[_user username] length] || ! [[_user address] length] ) return nil;
	return [NSString stringWithFormat:@"%@@%@", [_user username], [_user address]];
}

#pragma mark -
#pragma mark User Status

- (BOOL) quieted {
	return ( [[_room target] disciplineModesForMemberUser:_user] & MVChatRoomMemberDisciplineQuietedMode );
}

- (BOOL) voice {
	return ( [[_room target] modesForMemberUser:_user] & MVChatRoomMemberVoicedMode );
}

- (BOOL) operator {
	return ( [[_room target] modesForMemberUser:_user] & MVChatRoomMemberOperatorMode );
}

- (BOOL) halfOperator {
	return ( [[_room target] modesForMemberUser:_user] & MVChatRoomMemberHalfOperatorMode );
}

- (BOOL) roomAdministrator {
	return ( [[_room target] modesForMemberUser:_user] & MVChatRoomMemberAdministratorMode );
}

- (BOOL) roomFounder {
	return ( [[_room target] modesForMemberUser:_user] & MVChatRoomMemberFounderMode );
}

- (BOOL) serverOperator {
	return [_user isServerOperator];
}

- (BOOL) isLocalUser {
	return [_user isLocalUser];
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

	id uniqueId = [_user uniqueIdentifier];
	if( ! [uniqueId isEqual:[self nickname]] ) {
		if( [uniqueId isKindOfClass:[NSData class]] ) uniqueId = [uniqueId colBase64Encoding];
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

- (nullable id <JVChatListItem>) parent {
	return _room;
}

- (NSImage *) icon {
	NSUInteger modes = [[_room target] modesForMemberUser:_user];
	NSString *iconName = @"userNormal";

	if( [_user isServerOperator] ) iconName = @"userAdmin";
	else if( modes & MVChatRoomMemberFounderMode ) iconName = @"userFounder";
	else if( modes & MVChatRoomMemberAdministratorMode ) iconName = @"userSuperOperator";
	else if( modes & MVChatRoomMemberOperatorMode ) iconName = @"userOperator";
	else if( modes & MVChatRoomMemberHalfOperatorMode ) iconName = @"userHalfOperator";
	else if( modes & MVChatRoomMemberVoicedMode ) iconName = @"userVoice";

	return [NSImage imageFromPDF:iconName];
}

- (nullable NSImage *) statusImage {
	if( [self buddy] ) {
		switch( [_user status] ) {
			case MVChatUserAwayStatus:
				return [NSImage imageNamed:NSImageNameStatusUnavailable];
			case MVChatUserAvailableStatus:
				if( [_user idleTime] >= 600. )
					return [NSImage imageNamed:NSImageNameStatusPartiallyAvailable];
				return [NSImage imageNamed:NSImageNameStatusAvailable];
			default:
				return nil;
		}
	}

	return nil;
}

- (NSString *) title {
	if( [self isLocalUser] ) {
		JVBuddyName nameStyle = (JVBuddyName)[[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatSelfNameStyle"];
		if( nameStyle == JVBuddyFullName )
			return [self _selfCompositeName];
		if( nameStyle == JVBuddyGivenNickname )
			return [self _selfStoredNickname];
		return [self nickname];
	}

	JVBuddy *buddy = [self buddy];
	if( buddy ) {
		if( [JVBuddy preferredName] == JVBuddyFullName && [[buddy compositeName] length] )
			return [buddy compositeName];
		if( [JVBuddy preferredName] == JVBuddyGivenNickname && [[buddy givenNickname] length] )
			return [buddy givenNickname];
	}

	return [self nickname];
}

- (nullable NSString *) information {
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
	return [_room isEnabled] && ! ( [_user status] == MVChatUserAwayStatus || [_user idleTime] > 600. );
}

#pragma mark -

- (BOOL) acceptsDraggedFileOfType:(NSString *) type {
	return YES;
}

- (void) handleDraggedFile:(NSString *) path {
	BOOL passive = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSendFilesPassively"];
	[[MVFileTransferController defaultController] addFileTransfer:[_user sendFile:path passively:passive]];
}

#pragma mark -

- (IBAction) getInfo:(id) sender {
	[[JVInspectorController inspectorOfObject:self] show:sender];
}

- (NSMenu *) menu {
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
	NSMenuItem *item = nil;

	for( item in [_user standardMenuItems] )
		[menu addItem:item];

	NSUInteger localUserModes = ( [[self connection] localUser] ? [(MVChatRoom *)[_room target] modesForMemberUser:[[self connection] localUser]] : 0 );
	BOOL localUserIsOperator = ( localUserModes & MVChatRoomMemberOperatorMode );
	BOOL localUserIsHalfOperator = ( localUserModes & MVChatRoomMemberHalfOperatorMode );
	BOOL localUserIsAdministrator = ( localUserModes & MVChatRoomMemberAdministratorMode );
	BOOL localUserIsFounder = ( localUserModes & MVChatRoomMemberFounderMode );
//	BOOL localUserIsServerOperator = [[[self connection] localUser] isServerOperator];

	if( localUserIsHalfOperator || localUserIsOperator || localUserIsAdministrator || localUserIsFounder ) {
		[menu addItem:[NSMenuItem separatorItem]];

		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Kick From Room", "kick from room contextual menu - admin only" ) action:@selector( kick: ) keyEquivalent:@""];
		[item setTarget:self];
		[menu addItem:item];

		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Kick From Room...", "kick from room (customized) contextual menu - admin only" ) action:@selector( customKick: ) keyEquivalent:@""];
		[item setKeyEquivalentModifierMask:NSAlternateKeyMask];
		[item setAlternate:YES];
		[item setTarget:self];
		[menu addItem:item];

		if( [self address] ) {
			item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Ban From Room", "ban from room contextual menu - admin only" ) action:@selector( ban: ) keyEquivalent:@""];
			[item setTarget:self];
			[menu addItem:item];

			item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Ban From Room...", "ban from room (customized) contextual menu - admin only" ) action:@selector( customBan: ) keyEquivalent:@""];
			[item setKeyEquivalentModifierMask:NSAlternateKeyMask];
			[item setAlternate:YES];
			[item setTarget:self];
			[menu addItem:item];

			item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Kick & Ban From Room", "kickban from room contextual menu - admin only" ) action:@selector( kickban: ) keyEquivalent:@""];
			[item setTarget:self];
			[menu addItem:item];

			item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Kick & Ban From Room...", "kickban from room (customized) contextual menu - admin only" ) action:@selector( customKickban: ) keyEquivalent:@""];
			[item setKeyEquivalentModifierMask:NSAlternateKeyMask];
			[item setAlternate:YES];
			[item setTarget:self];
			[menu addItem:item];
		}
	}

	[menu addItem:[NSMenuItem separatorItem]];

	NSSet *features = [[self connection] supportedFeatures];

	if( ( localUserIsFounder ) && ( [features containsObject:MVChatRoomMemberFounderFeature] ) ) {
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Founder", "founder contextual menu - admin only") action:@selector( toggleFounderStatus: ) keyEquivalent:@""];
		[item setTarget:self];
		[menu addItem:item];
	}

	if( ( ( localUserIsAdministrator || localUserIsFounder ) && ( (localUserIsAdministrator && ! [self roomFounder]) || localUserIsFounder ) ) && ( [features containsObject:MVChatRoomMemberAdministratorFeature] ) ) {
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Administrator", "administrator contextual menu - admin only") action:@selector( toggleAdministratorStatus: ) keyEquivalent:@""];
		[item setTarget:self];
		[menu addItem:item];
	}

	if( ( localUserIsOperator || localUserIsAdministrator || localUserIsFounder ) && ( (localUserIsOperator && ! ([self roomAdministrator] || [self roomFounder])) || (localUserIsAdministrator && ! [self roomFounder]) || localUserIsFounder ) ) {
		if( [features containsObject:MVChatRoomMemberOperatorFeature] ) {
			item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Operator", "operator contextual menu - admin only") action:@selector( toggleOperatorStatus: ) keyEquivalent:@""];
			[item setTarget:self];
			[menu addItem:item];
		}

		if( [features containsObject:MVChatRoomMemberHalfOperatorFeature] ) {
			item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Half Operator", "half operator contextual menu - admin only") action:@selector( toggleHalfOperatorStatus: ) keyEquivalent:@""];
			[item setTarget:self];
			[menu addItem:item];
		}
	}

	if( localUserIsHalfOperator || localUserIsOperator || localUserIsAdministrator || localUserIsFounder ) {
		if( [features containsObject:MVChatRoomMemberVoicedFeature] && ( (localUserIsHalfOperator && ! ([self operator] || [self roomAdministrator] || [self roomFounder]) ) || (localUserIsOperator && ! ([self roomAdministrator] || [self roomFounder])) || (localUserIsAdministrator && ! [self roomFounder]) || localUserIsFounder ) ) {
			item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Voice", "voice contextual menu - admin only") action:@selector( toggleVoiceStatus: ) keyEquivalent:@""];
			[item setTarget:self];
			[menu addItem:item];
		}

		if( [features containsObject:MVChatRoomMemberQuietedFeature] ) {
			item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Quieted", "quieted contextual menu - admin only") action:@selector( toggleQuietedStatus: ) keyEquivalent:@""];
			[item setTarget:self];
			[menu addItem:item];
		}
	}

	if( [[[menu itemArray] lastObject] isSeparatorItem] )
		[menu removeItem:[[menu itemArray] lastObject]];

	return menu;
}

- (BOOL) validateMenuItem:(NSMenuItem *) menuItem {
	if( ! [[self connection] isConnected] ) return NO;
	if( [menuItem action] == @selector( toggleVoiceStatus: ) ) {
		if( [self voice] ) {
			[menuItem setState:NSOnState];
		} else {
			[menuItem setState:NSOffState];
		}
	} else if( [menuItem action] == @selector( toggleQuietedStatus: ) ) {
		if( [self quieted] ) {
			[menuItem setState:NSOnState];
		} else {
			[menuItem setState:NSOffState];
		}
	} else if( [menuItem action] == @selector( toggleOperatorStatus: ) ) {
		if( [self operator] ) {
			[menuItem setState:NSOnState];
		} else {
			[menuItem setState:NSOffState];
		}
	} else if( [menuItem action] == @selector( toggleHalfOperatorStatus: ) ) {
		if( [self halfOperator] ) {
			[menuItem setState:NSOnState];
		} else {
			[menuItem setState:NSOffState];
		}
	} else if( [menuItem action] == @selector( toggleAdministratorStatus: ) ) {
		if( [self roomAdministrator] ) {
			[menuItem setState:NSOnState];
		} else {
			[menuItem setState:NSOffState];
		}
	} else if( [menuItem action] == @selector( toggleFounderStatus: ) ) {
		if( [self roomFounder] ) {
			[menuItem setState:NSOnState];
		} else {
			[menuItem setState:NSOffState];
		}
	}
	return YES;
}

#pragma mark -
#pragma mark Scripting Support

- (NSNumber *) uniqueIdentifier {
	return [NSNumber numberWithUnsignedLong:(intptr_t)self];
}

- (nullable NSArray *) children {
	return nil;
}

#pragma mark -
#pragma mark GUI Actions

- (IBAction) doubleClicked:(nullable id) sender {
	[_user startChat:sender];
}

- (IBAction) startChat:(nullable id) sender {
	[_user startChat:sender];
}

- (IBAction) sendFile:(nullable id) sender {
	[_user sendFile:sender];
}

- (IBAction) addBuddy:(nullable id) sender {
	[_user addBuddy:sender];
}

- (IBAction) toggleIgnore:(nullable id) sender {
	[_user toggleIgnore:sender];
}

#pragma mark -
#pragma mark Operator Actions

- (IBAction) toggleFounderStatus:(id) sender {
	if( [self roomFounder] ) [[_room target] removeMode:MVChatRoomMemberFounderMode forMemberUser:_user];
	else [[_room target] setMode:MVChatRoomMemberFounderMode forMemberUser:_user];
}

- (IBAction) toggleAdministratorStatus:(id) sender {
	if( [self roomAdministrator] ) [[_room target] removeMode:MVChatRoomMemberAdministratorMode forMemberUser:_user];
	else [[_room target] setMode:MVChatRoomMemberAdministratorMode forMemberUser:_user];
}

- (IBAction) toggleOperatorStatus:(nullable id) sender {
	if( [self operator] ) [[_room target] removeMode:MVChatRoomMemberOperatorMode forMemberUser:_user];
	else [[_room target] setMode:MVChatRoomMemberOperatorMode forMemberUser:_user];
}

- (IBAction) toggleHalfOperatorStatus:(nullable id) sender {
	if( [self halfOperator] ) [[_room target] removeMode:MVChatRoomMemberHalfOperatorMode forMemberUser:_user];
	else [[_room target] setMode:MVChatRoomMemberHalfOperatorMode forMemberUser:_user];
}

- (IBAction) toggleVoiceStatus:(nullable id) sender {
	if( [self voice] ) [[_room target] removeMode:MVChatRoomMemberVoicedMode forMemberUser:_user];
	else [[_room target] setMode:MVChatRoomMemberVoicedMode forMemberUser:_user];
}

- (IBAction) toggleQuietedStatus:(nullable id) sender {
	if( [self quieted] ) [[_room target] removeDisciplineMode:MVChatRoomMemberDisciplineQuietedMode forMemberUser:_user];
	else [[_room target] setDisciplineMode:MVChatRoomMemberDisciplineQuietedMode forMemberUser:_user];
}

#pragma mark -

- (IBAction) kick:(nullable id) sender {
	[[_room target] kickOutMemberUser:_user forReason:nil];
}

- (IBAction) ban:(nullable id) sender {
	MVChatUser *user = [MVChatUser wildcardUserWithNicknameMask:nil andHostMask:[NSString stringWithFormat:@"*@%@", [self address]]];
	[[_room target] addBanForUser:user];
}

- (IBAction) customKick:(nullable id) sender {
	if( ! _nibLoaded ) _nibLoaded = [[NSBundle mainBundle] loadNibNamed:@"TSCustomBan" owner:self topLevelObjects:NULL];
	if( ! _nibLoaded ) { NSLog( @"Can't load TSCustomBan.nib" ); return; }

	[banTitle setStringValue:[NSString stringWithFormat:NSLocalizedString( @"Kick %@ from the %@ room.", "kick user from room" ), [self title], [_room title]]];
	[firstTitle setStringValue:NSLocalizedString( @"With reason:", "kick reason label" )];

	[firstField setStringValue:@""];
	[banWindow makeFirstResponder:firstField];

	[secondTitle setHidden:YES];
	[secondField setHidden:YES];

	NSRect frame = [banWindow frame];
	frame.size.height = ( frame.size.height - [firstField frame].origin.y ) + 60.;
	[banWindow setFrame:frame display:YES];

	[banButton setAction:@selector( closeKickSheet: )];
	[banButton setTitle:NSLocalizedString( @"Kick User", "kick user button" )];
	[banButton setTarget:self];

	[[NSApplication sharedApplication] beginSheet:banWindow modalForWindow:[[_room view] window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

- (IBAction) customBan:(nullable id) sender {
	if( ! _nibLoaded ) _nibLoaded = [[NSBundle mainBundle] loadNibNamed:@"TSCustomBan" owner:self topLevelObjects:NULL];
	if( ! _nibLoaded ) { NSLog( @"Can't load TSCustomBan.nib" ); return; }

	[banTitle setStringValue:[NSString stringWithFormat:NSLocalizedString( @"Ban %@ from the %@ room.", "ban user from room label" ), [self title], [_room title]]];
	[firstTitle setStringValue:NSLocalizedString( @"With hostmask:", "ban hostmask label")];

	if( [self username] && [self address] )
		[firstField setStringValue:[NSString stringWithFormat:@"%@!%@@%@", [self nickname], [self username], [self address]]];
	else [firstField setStringValue:@""];

	[banWindow makeFirstResponder:firstField];

	[secondTitle setHidden:YES];
	[secondField setHidden:YES];

	NSRect frame = [banWindow frame];
	frame.size.height = ( frame.size.height - [firstField frame].origin.y ) + 60.;
	[banWindow setFrame:frame display:YES];

	[banButton setAction:@selector( closeBanSheet: )];
	[banButton setTitle:NSLocalizedString( @"Ban User", "ban user button" )];
	[banButton setTarget:self];

	[[NSApplication sharedApplication] beginSheet:banWindow modalForWindow:[[_room view] window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

- (IBAction) kickban:(nullable id) sender {
	[self ban:nil];
	[self kick:nil];
}

- (IBAction) customKickban:(nullable id) sender {
	if( ! _nibLoaded ) _nibLoaded = [[NSBundle mainBundle] loadNibNamed:@"TSCustomBan" owner:self topLevelObjects:NULL];
	if( ! _nibLoaded ) { NSLog(@"Can't load TSCustomBan.nib"); return; }

	[banTitle setStringValue:[NSString stringWithFormat:NSLocalizedString( @"Kick and ban %@ from the %@ room.", "kickban user from room" ), [self title], [_room title]]];
	[banTitle sizeToFit];

	[firstTitle setStringValue:NSLocalizedString( @"With hostmask:", "ban hostmask" )];
	[secondTitle setStringValue:NSLocalizedString( @"And reason:", "kick reason (secondary)" )];

	if( [self username] && [self address] )
		[firstField setStringValue:[NSString stringWithFormat:@"%@!%@@%@", [self nickname], [self username], [self address]]];
	else [firstField setStringValue:@""];
	[secondField setStringValue:@""];

	[banWindow makeFirstResponder:firstField];

	[secondTitle setHidden:NO];
	[secondField setHidden:NO];

	NSRect frame = [banWindow frame];
	frame.size.height = ( frame.size.height - [secondField frame].origin.y ) + 60;
	[banWindow setFrame:frame display:YES];

	[banButton setAction:@selector( closeKickbanSheet: )];
	[banButton setTitle:NSLocalizedString( @"Kick & Ban User", "kick and ban user button" )];
	[banButton setTarget:self];

	[[NSApplication sharedApplication] beginSheet:banWindow modalForWindow:[[_room view] window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

- (IBAction) closeKickSheet:(nullable id) sender {
	[[NSApplication sharedApplication] endSheet:banWindow];
	[banWindow orderOut:self];

	NSAttributedString *reason = [[NSAttributedString alloc] initWithString:[firstField stringValue]];
	[[_room target] kickOutMemberUser:_user forReason:reason];
}

- (IBAction) closeBanSheet:(nullable id) sender {
	[[NSApplication sharedApplication] endSheet:banWindow];
	[banWindow orderOut:self];

	MVChatUser *user = [MVChatUser wildcardUserFromString:[firstField stringValue]];
	[[_room target] addBanForUser:user];
}

- (IBAction) closeKickbanSheet:(nullable id) sender {
	[[NSApplication sharedApplication] endSheet:banWindow];
	[banWindow orderOut:self];

	MVChatUser *user = [MVChatUser wildcardUserFromString:[firstField stringValue]];
	[[_room target] addBanForUser:user];

	NSAttributedString *reason = [[NSAttributedString alloc] initWithString:[secondField stringValue]];
	[[_room target] kickOutMemberUser:_user forReason:reason];
}

- (IBAction) cancelSheet:(nullable id) sender {
	[[NSApplication sharedApplication] endSheet:banWindow];
	[banWindow orderOut:self];
}

#pragma mark -

- (nullable id) valueForUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The member id %@ of chat room panel id %@ doesn't have the \"%@\" property.", [self uniqueIdentifier], [_room uniqueIdentifier], key]];
		return nil;
	}

	return [super valueForUndefinedKey:key];
}

- (void) setValue:(nullable id) value forUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The \"%@\" property of member id %@ of chat room panel id %@ is read only.", key, [self uniqueIdentifier], [_room uniqueIdentifier]]];
		return;
	}

	[super setValue:value forUndefinedKey:key];
}
@end

#pragma mark -

@implementation JVChatRoomMember (Private)
- (void) _detach {
	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatUserInformationUpdatedNotification object:_user];
	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatUserStatusChangedNotification object:_user];
	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatUserAwayStatusMessageChangedNotification object:_user];
	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatUserIdleTimeUpdatedNotification object:_user];

	_room = nil;
}

- (void) _refreshIcon:(NSNotification *) notification {
	[[_room windowController] reloadListItem:self andChildren:NO];
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

NS_ASSUME_NONNULL_END
