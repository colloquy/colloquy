#import <Cocoa/Cocoa.h>
#import <AddressBook/AddressBook.h>
#import <ChatCore/MVChatConnection.h>

#import "JVBuddy.h"
#import "MVConnectionsController.h"

NSString *JVBuddyCameOnlineNotification = @"JVBuddyCameOnlineNotification";
NSString *JVBuddyWentOfflineNotification = @"JVBuddyWentOfflineNotification";

NSString *JVBuddyNicknameCameOnlineNotification = @"JVBuddyNicknameCameOnlineNotification";
NSString *JVBuddyNicknameWentOfflineNotification = @"JVBuddyNicknameWentOfflineNotification";
NSString *JVBuddyNicknameStatusChangedNotification = @"JVBuddyNicknameStatusChangedNotification";

NSString *JVBuddyActiveNicknameChangedNotification = @"JVBuddyActiveNicknameChangedNotification";

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
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _nicknameChange: ) name:MVChatConnectionUserNicknameChangedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyOnline: ) name:MVChatConnectionBuddyIsOnlineNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyOffline: ) name:MVChatConnectionBuddyIsOfflineNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyAwayStatusChange: ) name:MVChatConnectionBuddyIsAwayNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyAwayStatusChange: ) name:MVChatConnectionBuddyIsUnawayNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _buddyIdleUpdate: ) name:MVChatConnectionBuddyIsIdleNotification object:nil];

		_person = [person retain];
		_nicknames = [[NSMutableSet set] retain];
		_onlineNicknames = [[NSMutableSet set] retain];
		_nicknameStatus = [[NSMutableDictionary dictionary] retain];
		_activeNickname = nil;

		ABMultiValue *value = [person valueForProperty:@"IRCNickname"];
		unsigned int i = 0, count = [value count];
		NSURL *url = nil;
		for( i = 0; i < count; i++ ) {
			url = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( [value valueAtIndex:i] ), MVURLEncodeString( [value labelAtIndex:i] )]];
			[_nicknames addObject:url];
			if( ! [self activeNickname] ) [self setActiveNickname:url];
		}

		[self registerWithApplicableConnections];
	}
	return self;
}

- (void) dealloc {
	[_person autorelease];
	[_nicknames autorelease];
	[_onlineNicknames autorelease];
	[_nicknameStatus autorelease];
	[_activeNickname autorelease];

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	_person = nil;
	_nicknames = nil;
	_onlineNicknames = nil;
	_nicknameStatus = nil;
	_activeNickname = nil;

	[super dealloc];
}

#pragma mark -

- (void) registerWithApplicableConnections {
	NSEnumerator *enumerator = [_nicknames objectEnumerator];
	NSEnumerator *connectionEnumerator = nil;
	MVChatConnection *connection = nil;
	NSURL *nick = nil;
	while( ( nick = [enumerator nextObject] ) ) {
		connectionEnumerator = [[[MVConnectionsController defaultManager] connectionsForServerAddress:[nick host]] objectEnumerator];
		while( ( connection = [connectionEnumerator nextObject] ) )
			[connection addUserToNotificationList:[nick user]];
	}
}

#pragma mark -

- (NSURL *) activeNickname {
	return [[_activeNickname retain] autorelease];
}

- (void) setActiveNickname:(NSURL *) nickname {
	[_activeNickname autorelease];
	_activeNickname = [nickname retain];
}

#pragma mark -

- (JVBuddyStatus) status {
	if( [self activeNickname] )
		return (JVBuddyStatus)[[[_nicknameStatus objectForKey:[self activeNickname]] objectForKey:@"status"] unsignedIntValue];
	return JVBuddyOfflineStatus;
}

- (BOOL) isOnline {
	return (BOOL)( [self status] != JVBuddyOfflineStatus );
}

- (NSTimeInterval) idleTime {
	if( [self activeNickname] )
		return (NSTimeInterval)[[[_nicknameStatus objectForKey:[self activeNickname]] objectForKey:@"idle"] doubleValue];
	return 0.;
}

- (NSString *) awayMessage {
	if( [self activeNickname] )
		return [[_nicknameStatus objectForKey:[self activeNickname]] objectForKey:@"awayMessage"];
	return nil;
}

#pragma mark -

- (NSSet *) nicknames {
	return [[_nicknames retain] autorelease];
}

- (NSSet *) onlineNicknames {
	return [[_onlineNicknames retain] autorelease];
}

#pragma mark -

- (void) addNickname:(NSURL *) nickname {
	if( [_nicknames containsObject:nickname] ) return;

	ABMutableMultiValue *value = [[[_person valueForProperty:@"IRCNickname"] mutableCopy] autorelease];
	[value addValue:[nickname user] withLabel:[nickname host]];
	[_person setValue:value forProperty:@"IRCNickname"];

	if( ! [_nicknames count] || ! [self activeNickname] )
		[self setActiveNickname:nickname];

	[_nicknames addObject:nickname];

	[[ABAddressBook sharedAddressBook] save];

	[self registerWithApplicableConnections];
}

- (void) removeNickname:(NSURL *) nickname {
	if( ! [_nicknames containsObject:nickname] ) return;

	ABMutableMultiValue *value = [[[_person valueForProperty:@"IRCNickname"] mutableCopy] autorelease];
	unsigned int i = 0, count = [value count];

	for( i = 0; i < count; i++ )
		if( [[nickname user] caseInsensitiveCompare:[value valueAtIndex:i]] == NSOrderedSame && [[nickname host] caseInsensitiveCompare:[value labelAtIndex:i]] == NSOrderedSame )
			[value removeValueAndLabelAtIndex:i];

	[_nicknames removeObject:nickname];
	[_onlineNicknames removeObject:nickname];
	[_person setValue:value forProperty:@"IRCNickname"];

	if( [[self activeNickname] isEqual:nickname] )
		[self setActiveNickname:( [_onlineNicknames count] ? [_onlineNicknames anyObject] : [_nicknames anyObject] )];

	[[ABAddressBook sharedAddressBook] save];
}

- (void) replaceNickname:(NSURL *) old withNickname:(NSURL *) new {
	[self removeNickname:old];
	[self addNickname:new];
}

#pragma mark -

- (NSImage *) picture {
	return [[[NSImage alloc] initWithData:[_person imageData]] autorelease];
}

- (NSString *) preferredName {
	switch( [[self class] preferredName] ) {
		default:
		case JVBuddyFullName:
			return [self compositeName];
		case JVBuddyStoredNickname:
			if( [_person valueForProperty:kABNicknameProperty] )
				return [_person valueForProperty:kABNicknameProperty];
		case JVBuddyActiveNickname:
			return [[self activeNickname] user];
	}
	return [[self activeNickname] user];
}

- (JVBuddyName) preferredNameWillReturn {
	NSString *firstName = [_person valueForProperty:kABFirstNameProperty];
	NSString *lastName = [_person valueForProperty:kABLastNameProperty];

	if( [firstName length] || [lastName length] ) return JVBuddyFullName;
	if( [(NSString *)[_person valueForProperty:kABNicknameProperty] length] ) return JVBuddyStoredNickname;

	return JVBuddyActiveNickname;
}

- (unsigned int) availableNames {
	unsigned int ret = JVBuddyActiveNickname;
	NSString *firstName = [_person valueForProperty:kABFirstNameProperty];
	NSString *lastName = [_person valueForProperty:kABLastNameProperty];

	if( [firstName length] || [lastName length] ) ret |= JVBuddyFullName;
	if( [(NSString *)[_person valueForProperty:kABNicknameProperty] length] ) ret |= JVBuddyStoredNickname;

	return ret;
}

- (NSString *) compositeName {
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

	return [[self activeNickname] user];
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

#pragma mark -

- (NSString *) uniqueIdentifier {
	return [_person uniqueId];
}

#pragma mark -

- (NSComparisonResult) availabilityCompare:(JVBuddy *) buddy {
	unsigned int b1 = 0, b2 = 0;

	if( [self status] == JVBuddyAwayStatus ) b1 = 2;
	else if( [self status] == JVBuddyIdleStatus ) b1 = 1;
	else if( [self status] == JVBuddyAvailableStatus ) b1 = 0;
	else b1 = 3;

	if( [buddy status] == JVBuddyAwayStatus ) b2 = 2;
	else if( [buddy status] == JVBuddyIdleStatus ) b2 = 1;
	else if( [buddy status] == JVBuddyAvailableStatus ) b2 = 0;
	else b2 = 3;

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
	NSString *name1 = [[self activeNickname] host];
	NSString *name2 = [[buddy activeNickname] host];
	NSComparisonResult ret = [name1 caseInsensitiveCompare:name2];
	return ( ret != NSOrderedSame ? ret : [self availabilityCompare:buddy] );
}

- (NSComparisonResult) nicknameCompare:(JVBuddy *) buddy {
	NSString *name1 = [[self activeNickname] user];
	NSString *name2 = [[buddy activeNickname] user];
	return [name1 caseInsensitiveCompare:name2];
}
@end

#pragma mark -

@implementation JVBuddy (JVBuddyPrivate)
- (void) _buddyOnline:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSString *who = [[notification userInfo] objectForKey:@"who"];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( who ), MVURLEncodeString( [connection server] )]];
	if( [_nicknames containsObject:url] ) {
		BOOL cameOnline = ( ! [_onlineNicknames count] ? YES : NO );
		[_onlineNicknames addObject:url];
		[_nicknameStatus setObject:[NSMutableDictionary dictionary] forKey:url];
		[[_nicknameStatus objectForKey:url] setObject:[NSNumber numberWithUnsignedInt:JVBuddyAvailableStatus] forKey:@"status"];
		if( [self status] == JVBuddyOfflineStatus ) [self setActiveNickname:url];
		if( cameOnline ) [[NSNotificationCenter defaultCenter] postNotificationName:JVBuddyCameOnlineNotification object:self userInfo:nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:JVBuddyNicknameCameOnlineNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:url, @"nickname", nil]];
		NSLog( @"_buddyOnline" );
	}
}

- (void) _buddyOffline:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSString *who = [[notification userInfo] objectForKey:@"who"];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( who ), MVURLEncodeString( [connection server] )]];
	if( [_onlineNicknames containsObject:url] ) {
		[_onlineNicknames removeObject:url];
		[[_nicknameStatus objectForKey:url] setObject:[NSNumber numberWithUnsignedInt:JVBuddyOfflineStatus] forKey:@"status"];
		if( [_onlineNicknames count] ) [self setActiveNickname:[_onlineNicknames anyObject]];
		[[NSNotificationCenter defaultCenter] postNotificationName:JVBuddyNicknameWentOfflineNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:url, @"nickname", nil]];
		if( ! [_onlineNicknames count] ) [[NSNotificationCenter defaultCenter] postNotificationName:JVBuddyWentOfflineNotification object:self userInfo:nil];
		NSLog( @"_buddyOffline" );
	}
}

- (void) _buddyIdleUpdate:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSString *who = [[notification userInfo] objectForKey:@"who"];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( who ), MVURLEncodeString( [connection server] )]];
	if( [_onlineNicknames containsObject:url] ) {
		NSNumber *idle = [[notification userInfo] objectForKey:@"idle"];
		[[_nicknameStatus objectForKey:url] setObject:idle forKey:@"idle"];
		if( [idle doubleValue] >= 600. && (JVBuddyStatus)[[[_nicknameStatus objectForKey:url] objectForKey:@"status"] unsignedIntValue] != JVBuddyAwayStatus ) {
			[[_nicknameStatus objectForKey:url] setObject:[NSNumber numberWithUnsignedInt:JVBuddyIdleStatus] forKey:@"status"];
		} else if( [idle doubleValue] < 600. && (JVBuddyStatus)[[[_nicknameStatus objectForKey:url] objectForKey:@"status"] unsignedIntValue] == JVBuddyIdleStatus ) {
			[[_nicknameStatus objectForKey:url] setObject:[NSNumber numberWithUnsignedInt:JVBuddyAvailableStatus] forKey:@"status"];
		}

		NSNotification *notification = [NSNotification notificationWithName:JVBuddyNicknameStatusChangedNotification object:self];
		[[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostWhenIdle coalesceMask:( NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender ) forModes:nil];
	}
}

- (void) _buddyAwayStatusChange:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSString *who = [[notification userInfo] objectForKey:@"who"];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( who ), MVURLEncodeString( [connection server] )]];
	if( [_onlineNicknames containsObject:url] ) {
		BOOL away = ( [[notification name] isEqualToString:MVChatConnectionBuddyIsAwayNotification] ? YES : NO );
		[[_nicknameStatus objectForKey:url] setObject:[NSNumber numberWithBool:away] forKey:@"away"];
		if( away ) {
			[[_nicknameStatus objectForKey:url] setObject:[NSNumber numberWithUnsignedInt:JVBuddyAwayStatus] forKey:@"status"];
		} else {
			NSTimeInterval idle = [[[_nicknameStatus objectForKey:url] objectForKey:@"idle"] doubleValue];
			if( idle >= 600. ) [[_nicknameStatus objectForKey:url] setObject:[NSNumber numberWithUnsignedInt:JVBuddyIdleStatus] forKey:@"status"];
			else [[_nicknameStatus objectForKey:url] setObject:[NSNumber numberWithUnsignedInt:JVBuddyAvailableStatus] forKey:@"status"];
		}

		NSNotification *notification = [NSNotification notificationWithName:JVBuddyNicknameStatusChangedNotification object:self];
		[[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostWhenIdle coalesceMask:( NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender ) forModes:nil];
	}
}

- (void) _registerWithConnection:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSEnumerator *enumerator = [_nicknames objectEnumerator];
	NSURL *nick = nil;

	while( ( nick = [enumerator nextObject] ) )
		if( [[nick host] caseInsensitiveCompare:[connection server]] == NSOrderedSame )
			[connection addUserToNotificationList:[nick user]];
}

- (void) _disconnected:(NSNotification *) notification {
	NSEnumerator *enumerator = [[[MVConnectionsController defaultManager] connections] objectEnumerator];
	MVChatConnection *connection = nil;
	unsigned int count = 0;

	while( ( connection = [enumerator nextObject] ) )
		if( [[connection server] caseInsensitiveCompare:[connection server]] == NSOrderedSame && [connection isConnected] )
			count++;

	if( count >= 1 ) return;

	connection = [notification object];
	enumerator = [[[_onlineNicknames copy] autorelease] objectEnumerator];
	NSURL *nick = nil;
	while( ( nick = [enumerator nextObject] ) ) {
		if( [[nick host] caseInsensitiveCompare:[connection server]] == NSOrderedSame ) {
			[_onlineNicknames removeObject:nick];
			[[_nicknameStatus objectForKey:nick] setObject:[NSNumber numberWithUnsignedInt:JVBuddyOfflineStatus] forKey:@"status"];
			[[NSNotificationCenter defaultCenter] postNotificationName:JVBuddyNicknameWentOfflineNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:nick, @"nickname", nil]];
			if( ! [_onlineNicknames count] ) [[NSNotificationCenter defaultCenter] postNotificationName:JVBuddyWentOfflineNotification object:self userInfo:nil];
		}
	}
}

- (void) _nicknameChange:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	NSString *who = [[notification userInfo] objectForKey:@"oldNickname"];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( who ), MVURLEncodeString( [connection server] )]];

	if( [_onlineNicknames containsObject:url] ) {
		NSString *new = [[notification userInfo] objectForKey:@"newNickname"];
		NSURL *urlNew = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@@%@", MVURLEncodeString( new ), MVURLEncodeString( [connection server] )]];

		[_nicknames removeObject:url];
		[_nicknames addObject:urlNew];

		[_onlineNicknames removeObject:url];
		[_onlineNicknames addObject:urlNew];

		NSMutableDictionary *info = [[[_nicknameStatus objectForKey:url] retain] autorelease];
		[_nicknameStatus removeObjectForKey:url];
		[_nicknameStatus setObject:info forKey:urlNew];

		if( [[self activeNickname] isEqual:url] ) [self setActiveNickname:urlNew];
	}
}
@end
