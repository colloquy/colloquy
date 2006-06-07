#import "JVBuddy.h"

#import <ChatCore/MVChatUserWatchRule.h>
#import "MVConnectionsController.h"

NSString *JVBuddyCameOnlineNotification = @"JVBuddyCameOnlineNotification";
NSString *JVBuddyWentOfflineNotification = @"JVBuddyWentOfflineNotification";

NSString *JVBuddyUserCameOnlineNotification = @"JVBuddyUserCameOnlineNotification";
NSString *JVBuddyUserWentOfflineNotification = @"JVBuddyUserWentOfflineNotification";
NSString *JVBuddyUserStatusChangedNotification = @"JVBuddyUserStatusChangedNotification";
NSString *JVBuddyUserIdleTimeUpdatedNotification = @"JVBuddyUserIdleTimeUpdatedNotification";

NSString *JVBuddyActiveUserChangedNotification = @"JVBuddyActiveUserChangedNotification";

static JVBuddyName _mainPreferredName = JVBuddyFullName;

NSString* const JVBuddyAddressBookIRCNicknameProperty = @"IRCNickname";
NSString* const JVBuddyAddressBookSpeechVoiceProperty = @"cc.javelin.colloquy.JVBuddy.TTSvoice";

@implementation JVBuddy
+ (JVBuddyName) preferredName {
	return _mainPreferredName;
}

+ (void) setPreferredName:(JVBuddyName) preferred {
	_mainPreferredName = preferred;
}

#pragma mark -

- (id) initWithDictionaryRepresentation:(NSDictionary *) dictionary {
	if( ( self = [super init] ) ) {
		_rules = [[NSMutableArray allocWithZone:nil] initWithCapacity:10];
		_users = [[NSMutableArray allocWithZone:nil] initWithCapacity:5];
		_activeUser = nil;

		NSEnumerator *enumerator = [[dictionary objectForKey:@"rules"] objectEnumerator];
		NSDictionary *ruleDictionary = nil;
		while( ( ruleDictionary = [enumerator nextObject] ) ) {
			MVChatUserWatchRule *rule = [[MVChatUserWatchRule allocWithZone:[self zone]] initWithDictionaryRepresentation:ruleDictionary];
			if( rule ) [self addWatchRule:rule];
			[rule release];
		}

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _registerWithConnection: ) name:MVChatConnectionDidConnectNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _disconnected: ) name:MVChatConnectionDidDisconnectNotification object:nil];

		[self registerWithApplicableConnections];
	}

	return self;
}

- (void) dealloc {
	[self unregisterWithApplicableConnections];

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_person release];
	[_rules release];
	[_users release];
	[_activeUser release];

	_person = nil;
	_users = nil;
	_rules = nil;
	_activeUser = nil;

	[super dealloc];
}

#pragma mark -

- (NSDictionary *) dictionaryRepresentation {
	NSMutableDictionary *dictionary = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:5];
	[dictionary setObject:_rules forKey:@"rules"];
	return dictionary;
}

#pragma mark -

- (void) registerWithApplicableConnections {
	NSEnumerator *enumerator = [_rules objectEnumerator];
	MVChatUserWatchRule *rule = nil;

	while( ( rule = [enumerator nextObject] ) ) {
		if( [[rule applicableServerDomains] count] ) {
			NSEnumerator *domainEnumerator = [[rule applicableServerDomains] objectEnumerator];
			NSString *domain = nil;

			while( ( domain = [domainEnumerator nextObject] ) ) {
				NSEnumerator *connectionEnumerator = [[[MVConnectionsController defaultController] connectionsForServerAddress:domain] objectEnumerator];
				MVChatConnection *connection = nil;

				while( ( connection = [connectionEnumerator nextObject] ) )
					[connection addChatUserWatchRule:rule];
			}
		} else {
			NSEnumerator *connectionEnumerator = [[[MVConnectionsController defaultController] connections] objectEnumerator];
			MVChatConnection *connection = nil;

			while( ( connection = [connectionEnumerator nextObject] ) )
				[connection addChatUserWatchRule:rule];
		}
	}
}

- (void) unregisterWithApplicableConnections {
	NSEnumerator *enumerator = [_rules objectEnumerator];
	MVChatUserWatchRule *rule = nil;

	while( ( rule = [enumerator nextObject] ) ) {
		if( [[rule applicableServerDomains] count] ) {
			NSEnumerator *domainEnumerator = [[rule applicableServerDomains] objectEnumerator];
			NSString *domain = nil;

			while( ( domain = [domainEnumerator nextObject] ) ) {
				NSEnumerator *connectionEnumerator = [[[MVConnectionsController defaultController] connectionsForServerAddress:domain] objectEnumerator];
				MVChatConnection *connection = nil;

				while( ( connection = [connectionEnumerator nextObject] ) )
					[connection removeChatUserWatchRule:rule];
			}
		} else {
			NSEnumerator *connectionEnumerator = [[[MVConnectionsController defaultController] connections] objectEnumerator];
			MVChatConnection *connection = nil;

			while( ( connection = [connectionEnumerator nextObject] ) )
				[connection removeChatUserWatchRule:rule];
		}
	}
}

#pragma mark -

- (MVChatUser *) activeUser {
	return _activeUser;
}

- (void) setActiveUser:(MVChatUser *) user {
	[_activeUser autorelease];
	_activeUser = [user retain];
}

#pragma mark -

- (MVChatUserStatus) status {
	return [[self activeUser] status];	
}

- (NSData *) awayStatusMessage {
	return [[self activeUser] awayStatusMessage];
}

#pragma mark -

- (BOOL) isOnline {
	return ( [_users count] > 0 ? YES : NO );
}

- (NSDate *) dateConnected {
	return [[self activeUser] dateConnected];	
}

- (NSDate *) dateDisconnected {
	return [[self activeUser] dateDisconnected];	
}

#pragma mark -

- (NSTimeInterval) idleTime {
	return [[self activeUser] idleTime];	
}

#pragma mark -

- (NSString *) displayName {
	switch( [[self class] preferredName] ) {
		default:
		case JVBuddyFullName:
			return [self compositeName];
		case JVBuddyGivenNickname:
			if( [[self givenNickname] length] )
				return [self givenNickname];
		case JVBuddyActiveNickname:
			return [self nickname];
	}

	return [self nickname];
}

- (NSString *) nickname {
	return [[self activeUser] nickname];
}

#pragma mark -

- (NSArray *) users {
	return _users;
}

#pragma mark -

- (void) addWatchRule:(MVChatUserWatchRule *) rule {
	if( [_rules containsObject:rule] ) return;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _ruleMatched: ) name:MVChatUserWatchRuleMatchedNotification object:rule];
	[_rules addObject:rule];
}

- (void) removeWatchRule:(MVChatUserWatchRule *) rule {
	if( ! [_rules containsObject:rule] ) return;
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MVChatUserWatchRuleMatchedNotification object:rule];
	[_rules removeObject:rule];
}

#pragma mark -

- (NSImage *) picture {
	return [[[NSImage alloc] initWithData:[_person imageData]] autorelease];
}

- (void) setPicture:(NSImage *) picture {
	[_person setImageData:[picture TIFFRepresentation]];
}

#pragma mark -

- (NSString *) compositeName {
	NSString *firstName = [self firstName];
	NSString *lastName = [self lastName];

	if( ! firstName && lastName ) return lastName;
	else if( firstName && ! lastName ) return firstName;
	else if( firstName && lastName ) {
		return [NSString stringWithFormat:@"%@ %@", firstName, lastName];
	}

	firstName = [self givenNickname];
	if( [firstName length] ) return firstName;

	return [[self activeUser] nickname];
}

- (NSString *) firstName {
	return [_person valueForProperty:kABFirstNameProperty];
}

- (NSString *) lastName {
	return [_person valueForProperty:kABLastNameProperty];
}

- (NSString *) primaryEmail {
	ABMultiValue *value = [_person valueForProperty:kABEmailProperty];
	return [value valueAtIndex:[value indexForIdentifier:[value primaryIdentifier]]];
}

- (NSString *) givenNickname {
	return [_person valueForProperty:kABNicknameProperty];
}

- (NSString *) speechVoice {
	return [_person valueForProperty:JVBuddyAddressBookSpeechVoiceProperty];
}

#pragma mark -

- (void) setFirstName:(NSString *) name {
	[_person setValue:name forProperty:kABFirstNameProperty];
	[[ABAddressBook sharedAddressBook] save];
}

- (void) setLastName:(NSString *) name {
	[_person setValue:name forProperty:kABLastNameProperty];
	[[ABAddressBook sharedAddressBook] save];
}

- (void) setPrimaryEmail:(NSString *) email {
	ABMutableMultiValue *value = [[[_person valueForProperty:kABEmailProperty] mutableCopy] autorelease];

	if( ! value ) {
		value = [[[ABMutableMultiValue alloc] init] autorelease];
		[value addValue:email withLabel:kABOtherLabel];
	} else [value replaceValueAtIndex:[value indexForIdentifier:[value primaryIdentifier]] withValue:email];

	[_person setValue:value forProperty:kABEmailProperty];
	[[ABAddressBook sharedAddressBook] save];
}

- (void) setGivenNickname:(NSString *) name {
	[_person setValue:name forProperty:kABNicknameProperty];
	[[ABAddressBook sharedAddressBook] save];
}

- (void) setSpeechVoice:(NSString *) voice {
	if( [voice length] ) [_person setValue:voice forProperty:JVBuddyAddressBookSpeechVoiceProperty];	
	else [_person removeValueForProperty:JVBuddyAddressBookSpeechVoiceProperty];	
	[[ABAddressBook sharedAddressBook] save];
}

#pragma mark -

- (NSString *) uniqueIdentifier {
	return [_person uniqueId];
}

- (ABPerson *) person {
	return _person;
}

- (void) editInAddressBook {
	if( ! _person ) return;
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"addressbook://%@?edit", [_person uniqueId]]];
	[[NSWorkspace sharedWorkspace] openURL:url];
}

- (void) viewInAddressBook {
	if( ! _person ) return;
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"addressbook://%@", [_person uniqueId]]];
	[[NSWorkspace sharedWorkspace] openURL:url];
}

#pragma mark -
#pragma mark Comparisons

- (NSComparisonResult) availabilityCompare:(JVBuddy *) buddy {
	unsigned int b1 = 0, b2 = 0;

	if( [self status] == MVChatUserAwayStatus ) b1 = 2;
	else if( [self status] == MVChatUserAvailableStatus ) {
		if( [self idleTime] >= 600. ) b1 = 1;
		else b1 = 0;
	} else b1 = 3;

	if( [buddy status] == MVChatUserAwayStatus ) b2 = 2;
	else if( [buddy status] == MVChatUserAvailableStatus ) {
		if( [buddy idleTime] >= 600. ) b2 = 1;
		else b2 = 0;
	} else b2 = 3;

	if( b1 > b2 ) return NSOrderedDescending;
	else if( b1 < b2 ) return NSOrderedAscending;
	return [self lastNameCompare:buddy];
}

- (NSComparisonResult) firstNameCompare:(JVBuddy *) buddy {
	NSComparisonResult ret = NSOrderedSame;
	NSString *name1 = [self firstName];
	NSString *name2 = [buddy firstName];

	if( ! [name1 length] ) name1 = [self lastName];
	if( ! [name2 length] ) name2 = [buddy lastName];

	if( ! [name1 length] && [name2 length] ) return NSOrderedAscending;
	else if( ! [name2 length] && [name1 length]  ) return NSOrderedDescending;

	ret = [name1 localizedCaseInsensitiveCompare:name2];
	if( ret != NSOrderedSame ) return ret;

	name1 = [self lastName];
	name2 = [buddy lastName];

	if( ! [name1 length] && [name2 length] ) return NSOrderedAscending;
	else if( ! [name2 length] && [name1 length]  ) return NSOrderedDescending;

	return [name1 localizedCaseInsensitiveCompare:name2];
}

- (NSComparisonResult) lastNameCompare:(JVBuddy *) buddy {
	NSComparisonResult ret = NSOrderedSame;
	NSString *name1 = [self lastName];
	NSString *name2 = [buddy lastName];

	if( ! [name1 length] ) name1 = [self firstName];
	if( ! [name2 length] ) name2 = [buddy firstName];

	if( ! [name1 length] && [name2 length] ) return NSOrderedAscending;
	else if( ! [name2 length] && [name1 length]  ) return NSOrderedDescending;

	ret = [name1 localizedCaseInsensitiveCompare:name2];
	if( ret != NSOrderedSame ) return ret;

	name1 = [self firstName];
	name2 = [buddy firstName];

	if( ! [name1 length] && [name2 length] ) return NSOrderedAscending;
	else if( ! [name2 length] && [name1 length]  ) return NSOrderedDescending;

	return [name1 localizedCaseInsensitiveCompare:name2];
}

- (NSComparisonResult) serverCompare:(JVBuddy *) buddy {
	NSString *name1 = [[self activeUser] serverAddress];
	NSString *name2 = [[buddy activeUser] serverAddress];
	NSComparisonResult ret = [name1 caseInsensitiveCompare:name2];
	return ( ret != NSOrderedSame ? ret : [self availabilityCompare:buddy] );
}

- (NSComparisonResult) nicknameCompare:(JVBuddy *) buddy {
	NSString *name1 = [[self activeUser] nickname];
	NSString *name2 = [[buddy activeUser] nickname];
	return [name1 caseInsensitiveCompare:name2];
}
@end

#pragma mark -

@implementation JVBuddy (JVBuddyPrivate)
- (void) _buddyOnline:(NSNotification *) notification {
	MVChatUser *user = [notification object];
	BOOL cameOnline = ( ! [_users count] ? YES : NO );
	[_users addObject:user];

	if( [self status] != MVChatUserAvailableStatus || [self status] != MVChatUserAwayStatus ) [self setActiveUser:user];
	if( cameOnline ) [[NSNotificationCenter defaultCenter] postNotificationName:JVBuddyCameOnlineNotification object:self userInfo:nil];
}

- (void) _buddyOffline:(NSNotification *) notification {
	MVChatUser *user = [notification object];
	[_users removeObject:user];

	if( [[self activeUser] isEqualToChatUser:user] ) {
		if( [_users count] ) [self setActiveUser:[_users lastObject]];
		else [self setActiveUser:nil];
	}

	if( ! [_users count] ) [[NSNotificationCenter defaultCenter] postNotificationName:JVBuddyWentOfflineNotification object:self userInfo:nil];
}

- (void) _buddyIdleUpdate:(NSNotification *) notification {
	MVChatUser *user = [notification object];
	NSNotification *note = [NSNotification notificationWithName:JVBuddyUserIdleTimeUpdatedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", nil]];
	[[NSNotificationQueue defaultQueue] enqueueNotification:note postingStyle:NSPostASAP coalesceMask:( NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender ) forModes:nil];
}

- (void) _buddyStatusChanged:(NSNotification *) notification {
	MVChatUser *user = [notification object];
	NSNotification *note = [NSNotification notificationWithName:JVBuddyUserStatusChangedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", nil]];
	[[NSNotificationQueue defaultQueue] enqueueNotification:note postingStyle:NSPostASAP coalesceMask:( NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender ) forModes:nil];
}

- (void) _registerWithConnection:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSEnumerator *enumerator = [_rules objectEnumerator];
	MVChatUserWatchRule *rule = nil;

	while( ( rule = [enumerator nextObject] ) ) {
		if( [[rule applicableServerDomains] count] ) {
			NSEnumerator *domainEnumerator = [[rule applicableServerDomains] objectEnumerator];
			NSString *domain = nil;

			while( ( domain = [domainEnumerator nextObject] ) ) {
				if( [[connection server] compare:domain options:( NSCaseInsensitiveSearch | NSLiteralSearch | NSBackwardsSearch | NSAnchoredSearch )] == NSOrderedSame )
					[connection addChatUserWatchRule:rule];
			}
		} else [connection addChatUserWatchRule:rule];
	}
}

- (void) _disconnected:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSEnumerator *enumerator = [[[_users copy] autorelease] objectEnumerator];
	MVChatUser *user = nil;

	while( ( user = [enumerator nextObject] ) ) {
		if( [[user connection] isEqual:connection] ) {
			[_users removeObject:user];
			if( ! [_users count] ) [[NSNotificationCenter defaultCenter] postNotificationName:JVBuddyWentOfflineNotification object:self userInfo:nil];
		}
	}

	if( [[[self activeUser] connection] isEqual:connection] )
		[self setActiveUser:[_users lastObject]];
}

- (void) _ruleMatched:(NSNotification *) notification {
	MVChatUser *user = [[notification userInfo] objectForKey:@"user"];

	[_users addObject:user];
	if( ! [self activeUser] )
		[self setActiveUser:user];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyOnline: ) name:MVChatConnectionWatchedUserOfflineNotification object:user];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyOffline: ) name:MVChatConnectionWatchedUserOfflineNotification object:user];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyIdleUpdate: ) name:MVChatUserIdleTimeUpdatedNotification object:user];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyStatusChanged: ) name:MVChatUserStatusChangedNotification object:user];
}
@end
/*
#pragma mark -

@implementation JVBuddy (JVBuddyScripting)
- (NSDictionary *) activeNicknameDictionary {
	MVChatConnection *connection = [[MVConnectionsController defaultController] connectionForServerAddress:[[self activeNickname] host]];
	return [NSDictionary dictionaryWithObjectsAndKeys:connection, @"connection", [[self activeNickname] user], @"nickname", nil];
}

- (NSArray *) nicknamesArray {
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[_users count]];
	NSEnumerator *enumerator = [_users objectEnumerator];
	NSURL *nick = nil;

	while( ( nick = [enumerator nextObject] ) ) {
		MVChatConnection *connection = [[MVConnectionsController defaultController] connectionForServerAddress:[nick host]];
		if( ! connection ) continue;
		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:connection, @"connection", [nick user], @"nickname", nil];
		[ret addObject:info];
	}

	return ret;
}

- (NSArray *) onlineNicknamesArray {
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[_users count]];
	NSEnumerator *enumerator = [_users objectEnumerator];
	NSURL *nick = nil;

	while( ( nick = [enumerator nextObject] ) ) {
		MVChatConnection *connection = [[MVConnectionsController defaultController] connectionForServerAddress:[nick host]];
		if( ! connection ) continue;
		NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:connection, @"connection", [nick user], @"nickname", nil];
		[ret addObject:info];
	}

	return ret;
}

- (void) editInAddressBookScriptCommand:(NSScriptCommand *) command {
	[self editInAddressBook];
}

- (void) viewInAddressBookScriptCommand:(NSScriptCommand *) command {
	[self viewInAddressBook];
}
@end */