#import "JVBuddy.h"
#import "MVConnectionsController.h"

NSString *JVBuddyCameOnlineNotification = @"JVBuddyCameOnlineNotification";
NSString *JVBuddyWentOfflineNotification = @"JVBuddyWentOfflineNotification";

NSString *JVBuddyUserCameOnlineNotification = @"JVBuddyUserCameOnlineNotification";
NSString *JVBuddyUserWentOfflineNotification = @"JVBuddyUserWentOfflineNotification";
NSString *JVBuddyUserStatusChangedNotification = @"JVBuddyUserStatusChangedNotification";
NSString *JVBuddyUserIdleTimeUpdatedNotification = @"JVBuddyUserIdleTimeUpdatedNotification";

NSString *JVBuddyActiveUserChangedNotification = @"JVBuddyActiveUserChangedNotification";

static JVBuddyName _mainPreferredName = JVBuddyFullName;

@implementation JVBuddy
+ (JVBuddyName) preferredName {
	extern JVBuddyName _mainPreferredName;
	return _mainPreferredName;
}

+ (void) setPreferredName:(JVBuddyName) preferred {
	extern JVBuddyName _mainPreferredName;
	_mainPreferredName = preferred;
}

+ (id) buddyWithPerson:(ABPerson *) person {
	return [[[[self class] alloc] initWithPerson:person] autorelease];
}

+ (id) buddyWithUniqueIdentifier:(NSString *) identifier {
	ABRecord *person = [[ABAddressBook sharedAddressBook] recordForUniqueId:identifier];
	if( [person isKindOfClass:[ABPerson class]] )
		return [[[[self class] alloc] initWithPerson:(ABPerson *)person] autorelease];
	return nil;
}

#pragma mark -

- (id) initWithPerson:(ABPerson *) person {
	if( ( self = [super init] ) ) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _registerWithConnection: ) name:MVChatConnectionDidConnectNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _disconnected: ) name:MVChatConnectionDidDisconnectNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyOnline: ) name:MVChatConnectionWatchedUserOnlineNotification object:nil];
//		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyAwayStatusChange: ) name:MVChatConnectionBuddyIsAwayNotification object:nil];
//		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyAwayStatusChange: ) name:MVChatConnectionBuddyIsUnawayNotification object:nil];

		_person = [person retain];
		_users = [[NSMutableArray array] retain];
		_onlineUsers = [[NSMutableArray array] retain];
		_activeUser = nil;

		ABMultiValue *value = [person valueForProperty:@"IRCNickname"];
		unsigned int i = 0, count = [value count];
		MVChatUser *user = nil;

		for( i = 0; i < count; i++ ) {
			user = [MVChatUser wildcardUserWithNicknameMask:[NSString stringWithFormat:@"%@@%@", [value valueAtIndex:i], [value labelAtIndex:i]] andHostMask:nil];
			[_users addObject:user];
			if( ! [self activeUser] ) [self setActiveUser:user];
		}

		[self registerWithApplicableConnections];
	}
	return self;
}

- (void) dealloc {
	[self unregisterWithApplicableConnections];

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_person release];
	[_users release];
	[_onlineUsers release];
	[_activeUser release];

	_person = nil;
	_users = nil;
	_onlineUsers = nil;
	_activeUser = nil;

	[super dealloc];
}

#pragma mark -

- (void) registerWithApplicableConnections {
	NSEnumerator *enumerator = [_users objectEnumerator];
	NSEnumerator *connectionEnumerator = nil;
	MVChatConnection *connection = nil;
	MVChatUser *user = nil;

	while( ( user = [enumerator nextObject] ) ) {
		connectionEnumerator = [[[MVConnectionsController defaultController] connectionsForServerAddress:[user serverAddress]] objectEnumerator];
		while( ( connection = [connectionEnumerator nextObject] ) )
			[connection startWatchingUser:user];
	}
}

- (void) unregisterWithApplicableConnections {
	NSEnumerator *enumerator = [_users objectEnumerator];
	NSEnumerator *connectionEnumerator = nil;
	MVChatConnection *connection = nil;
	MVChatUser *user = nil;

	while( ( user = [enumerator nextObject] ) ) {
		connectionEnumerator = [[[MVConnectionsController defaultController] connectionsForServerAddress:[user serverAddress]] objectEnumerator];
		while( ( connection = [connectionEnumerator nextObject] ) )
			[connection stopWatchingUser:user];
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

- (NSAttributedString *) awayStatusMessage {
	return [[self activeUser] awayStatusMessage];
}

#pragma mark -

- (BOOL) isOnline {
	return ( [_onlineUsers count] > 0 ? YES : NO );
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
	return [[_users retain] autorelease];
}

- (NSArray *) onlineUsers {
	return [[_onlineUsers retain] autorelease];
}

#pragma mark -

- (void) addUser:(MVChatUser *) user {
	if( [_users containsObject:user] ) return;

	ABMutableMultiValue *value = [[[_person valueForProperty:@"IRCNickname"] mutableCopy] autorelease];
	[value addValue:[user nickname] withLabel:[user serverAddress]];
	[_person setValue:value forProperty:@"IRCNickname"];

	if( ! [_users count] || ! [self activeUser] )
		[self setActiveUser:user];

	[_users addObject:user];

	[[ABAddressBook sharedAddressBook] save];

	[self registerWithApplicableConnections];
}

- (void) removeUser:(MVChatUser *) user {
	if( ! [_users containsObject:user] ) return;

	ABMutableMultiValue *value = [[[_person valueForProperty:@"IRCNickname"] mutableCopy] autorelease];
	int i = 0, count = [value count];

	for( i = count - 1; i >= 0; i-- )
		if( [[user nickname] caseInsensitiveCompare:[value valueAtIndex:i]] == NSOrderedSame && [[user serverAddress] caseInsensitiveCompare:[value labelAtIndex:i]] == NSOrderedSame )
			[value removeValueAndLabelAtIndex:i];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:user];

	[_users removeObject:user];
	[_onlineUsers removeObject:user];
	[_person setValue:value forProperty:@"IRCNickname"];

	if( [[self activeUser] isEqual:user] )
		[self setActiveUser:( [_onlineUsers count] ? [_onlineUsers lastObject] : [_users lastObject] )];

	[[ABAddressBook sharedAddressBook] save];
}

- (void) replaceUser:(MVChatUser *) oldUser withUser:(MVChatUser *) newUser {
	[self removeUser:oldUser];
	[self addUser:newUser];
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

#pragma mark -

- (NSString *) uniqueIdentifier {
	return [_person uniqueId];
}

- (ABPerson *) person {
	return [[_person retain] autorelease];
}

- (void) editInAddressBook {
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"addressbook://%@?edit", [_person uniqueId]]];
	[[NSWorkspace sharedWorkspace] openURL:url];
}

- (void) viewInAddressBook {
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
	if( [_users containsObject:user] ) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyOffline: ) name:MVChatConnectionWatchedUserOfflineNotification object:user];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyIdleUpdate: ) name:MVChatUserIdleTimeUpdatedNotification object:user];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyStatusChanged: ) name:MVChatUserStatusChangedNotification object:user];

		BOOL cameOnline = ( ! [_onlineUsers count] ? YES : NO );
		if( [[self activeUser] isEqual:user] ) [self setActiveUser:user]; // will remove the placeholder (wildcard user)
		[_users removeObject:user]; // will remove the placeholder (wildcard user)
		[_users addObject:user];
		[_onlineUsers addObject:user];

		if( [self status] != MVChatUserAvailableStatus || [self status] != MVChatUserAwayStatus ) [self setActiveUser:user];
		if( cameOnline ) [[NSNotificationCenter defaultCenter] postNotificationName:JVBuddyCameOnlineNotification object:self userInfo:nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:JVBuddyUserCameOnlineNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", nil]];
	}
}

- (void) _buddyOffline:(NSNotification *) notification {
	MVChatUser *user = [notification object];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:user];

	[_onlineUsers removeObject:user];

	if( [_onlineUsers count] ) [self setActiveUser:[_onlineUsers lastObject]];
	if( ! [_onlineUsers count] ) [[NSNotificationCenter defaultCenter] postNotificationName:JVBuddyWentOfflineNotification object:self userInfo:nil];

	[[NSNotificationCenter defaultCenter] postNotificationName:JVBuddyUserWentOfflineNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", nil]];
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
	NSEnumerator *enumerator = [_users objectEnumerator];
	MVChatUser *user = nil;

	while( ( user = [enumerator nextObject] ) ) {
		if( [[user connection] isEqual:connection] || [[user serverAddress] caseInsensitiveCompare:[connection server]] == NSOrderedSame ) {
			[connection startWatchingUser:user];
		}
	}
}

- (void) _disconnected:(NSNotification *) notification {
	NSEnumerator *enumerator = [[[MVConnectionsController defaultController] connections] objectEnumerator];
	MVChatConnection *connection = nil;
	unsigned int count = 0;

	while( ( connection = [enumerator nextObject] ) )
		if( [[connection server] caseInsensitiveCompare:[connection server]] == NSOrderedSame && [connection isConnected] )
			count++;

	if( count >= 1 ) return;

	connection = [notification object];
	enumerator = [[[_onlineUsers copy] autorelease] objectEnumerator];
	MVChatUser *user = nil;

	while( ( user = [enumerator nextObject] ) ) {
		if( [[user connection] isEqual:connection] || [[user serverAddress] caseInsensitiveCompare:[connection server]] == NSOrderedSame ) {
			[_onlineUsers removeObject:user];
//			[[NSNotificationCenter defaultCenter] postNotificationName:JVBuddyNicknameWentOfflineNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:nick, @"nickname", nil]];
			if( ! [_onlineUsers count] ) [[NSNotificationCenter defaultCenter] postNotificationName:JVBuddyWentOfflineNotification object:self userInfo:nil];
		}
	}
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
	NSEnumerator *enumerator = [_onlineUsers objectEnumerator];
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