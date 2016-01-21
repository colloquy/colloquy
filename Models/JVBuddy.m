#import "JVBuddy.h"
#import "MVConnectionsController.h"

#import <AddressBook/AddressBook.h>

NSString *JVBuddyCameOnlineNotification = @"JVBuddyCameOnlineNotification";
NSString *JVBuddyWentOfflineNotification = @"JVBuddyWentOfflineNotification";

NSString *JVBuddyUserCameOnlineNotification = @"JVBuddyUserCameOnlineNotification";
NSString *JVBuddyUserWentOfflineNotification = @"JVBuddyUserWentOfflineNotification";
NSString *JVBuddyUserStatusChangedNotification = @"JVBuddyUserStatusChangedNotification";
NSString *JVBuddyUserIdleTimeUpdatedNotification = @"JVBuddyUserIdleTimeUpdatedNotification";

NSString *JVBuddyActiveUserChangedNotification = @"JVBuddyActiveUserChangedNotification";

static JVBuddyName _mainPreferredName = JVBuddyFullName;

@interface JVBuddy (Private)
- (void) _addUser:(MVChatUser *) user;
- (void) _removeUser:(MVChatUser *) user;
- (void) _buddyIdleUpdate:(NSNotification *) notification;
- (void) _buddyStatusChanged:(NSNotification *) notification;
- (void) _registerWithConnection:(NSNotification *) notification;
- (void) _disconnected:(NSNotification *) notification;
- (void) _ruleMatched:(NSNotification *) notification;
- (void) _ruleUserRemoved:(NSNotification *) notification;
@end

@implementation JVBuddy {
	NSMutableArray *_rules;
	NSMutableSet *_users;
}

+ (JVBuddyName) preferredName {
	return _mainPreferredName;
}

+ (void) setPreferredName:(JVBuddyName) preferred {
	_mainPreferredName = preferred;
}

#pragma mark -

- (instancetype) init {
	if( ( self = [super init] ) ) {
		_rules = [[NSMutableArray alloc] initWithCapacity:5];
		_users = [[NSMutableSet alloc] initWithCapacity:5];
		_uniqueIdentifier = [NSString locallyUniqueString];

		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _registerWithConnection: ) name:MVChatConnectionDidConnectNotification object:nil];
		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _disconnected: ) name:MVChatConnectionDidDisconnectNotification object:nil];
	}

	return self;
}

- (instancetype) initWithDictionaryRepresentation:(NSDictionary *) dictionary {
	if( ( self = [self init] ) ) {
		NSData *data = dictionary[@"picture"];
		if( [data isKindOfClass:[NSData class]] && [data length] )
			_picture = [NSKeyedUnarchiver unarchiveObjectWithData:data];

		NSString *string = dictionary[@"firstName"];
		if( [string isKindOfClass:[NSString class]] )
			_firstName = [string copy];

		string = dictionary[@"lastName"];
		if( [string isKindOfClass:[NSString class]] )
			_lastName = [string copy];

		string = dictionary[@"primaryEmail"];
		if( [string isKindOfClass:[NSString class]] )
			_primaryEmail = [string copy];

		string = dictionary[@"givenNickname"];
		if( [string isKindOfClass:[NSString class]] )
			_givenNickname = [string copy];

		string = dictionary[@"speechVoice"];
		if( [string isKindOfClass:[NSString class]] )
			_speechVoice = [string copy];

		string = dictionary[@"uniqueIdentifier"];
		if( [string isKindOfClass:[NSString class]] ) {
			_uniqueIdentifier = [string copy];
		}

		if( ! [_uniqueIdentifier length] ) {
			_uniqueIdentifier = [NSString locallyUniqueString];
		}

		string = dictionary[@"addressBookPersonRecord"];
		if( [string isKindOfClass:[NSString class]] )
			_person = (ABPerson *)[[ABAddressBook sharedAddressBook] recordForUniqueId:string];

		for( NSDictionary *ruleDictionary in dictionary[@"rules"] ) {
			MVChatUserWatchRule *rule = [[MVChatUserWatchRule alloc] initWithDictionaryRepresentation:ruleDictionary];
			if( rule ) [self addWatchRule:rule];
		}
	}

	return self;
}

- (void) dealloc {
	[self unregisterWithConnections];

	[[NSNotificationCenter chatCenter] removeObserver:self];
}

#pragma mark -

- (NSDictionary *) dictionaryRepresentation {
	NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] initWithCapacity:8];

	NSMutableArray *rules = [[NSMutableArray alloc] initWithCapacity:[_rules count]];

	for( MVChatUserWatchRule *rule in _rules ) {
		NSDictionary *dictRep = [rule dictionaryRepresentation];
		if( dictRep ) [rules addObject:dictRep];
	}

	dictionary[@"rules"] = rules;

	if( _picture ) {
		NSData *imageData = [NSKeyedArchiver archivedDataWithRootObject:_picture];
		if( imageData ) dictionary[@"picture"] = imageData;
	}

	if( _firstName )
		dictionary[@"firstName"] = _firstName;

	if( _lastName )
		dictionary[@"lastName"] = _lastName;

	if( _primaryEmail )
		dictionary[@"primaryEmail"] = _primaryEmail;

	if( _givenNickname )
		dictionary[@"givenNickname"] = _givenNickname;

	if( _speechVoice )
		dictionary[@"speechVoice"] = _speechVoice;

	if( _uniqueIdentifier )
		dictionary[@"uniqueIdentifier"] = _uniqueIdentifier;

	if( _person && [_person uniqueId] )
		dictionary[@"addressBookPersonRecord"] = [_person uniqueId];

	return dictionary;
}

#pragma mark -

- (void) registerWithConnection:(MVChatConnection *) connection {
	for( MVChatUserWatchRule *rule in _rules ) {
		if( [[rule applicableServerDomains] count] ) {
			for( NSString *domain in [rule applicableServerDomains] ) {
				if( [[[connection server] stringWithDomainNameSegmentOfAddress] isCaseInsensitiveEqualToString:[domain stringWithDomainNameSegmentOfAddress]] ) {
					[connection addChatUserWatchRule:rule];
					break;
				}
			}
		} else [connection addChatUserWatchRule:rule];
	}
}

- (void) registerWithApplicableConnections {
	for( MVChatUserWatchRule *rule in _rules ) {
		if( [[rule applicableServerDomains] count] ) {
			for( NSString *domain in [rule applicableServerDomains] ) {
				for( MVChatConnection *connection in [[MVConnectionsController defaultController] connectionsForServerAddress:domain] )
					[connection addChatUserWatchRule:rule];
			}
		} else {
			for( MVChatConnection *connection in [[MVConnectionsController defaultController] connections] )
				[connection addChatUserWatchRule:rule];
		}
	}
}
	
- (void) unregisterWithConnection:(MVChatConnection *) connection {
	for( MVChatUserWatchRule *rule in _rules )
		[connection removeChatUserWatchRule:rule];

	for( MVChatUser *user in [_users copy] )
		if( [[user connection] isEqual:connection] )
			[_users removeObject:user];

	if( [[[self activeUser] connection] isEqual:connection] )
		[self setActiveUser:[_users anyObject]];
}

- (void) unregisterWithConnections {
	for( MVChatUserWatchRule *rule in _rules ) {
		for (MVChatConnection *connection in [[MVConnectionsController defaultController] connections] )
			[connection removeChatUserWatchRule:rule];
	}

	[_users removeAllObjects];
	[self setActiveUser:nil];
}

#pragma mark -

- (void) setActiveUser:(MVChatUser *) user {
	if( [_activeUser isEqual:user] )
		return;

	_activeUser = user;

	[[NSNotificationCenter chatCenter] postNotificationName:JVBuddyActiveUserChangedNotification object:self userInfo:nil];
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
	return ( [_users count] > 0 );
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
			if( [[self compositeName] length] )
				return [self compositeName];
		case JVBuddyGivenNickname:
			if( [[self givenNickname] length] )
				return [self givenNickname];
		case JVBuddyActiveNickname:
			return [self nickname];
	}
}

- (NSString *) nickname {
	return [[self activeUser] nickname];
}

#pragma mark -

- (NSSet *) users {
	return _users;
}

#pragma mark -

- (NSArray *) watchRules {
	return _rules;
}

- (void) addWatchRule:(MVChatUserWatchRule *) rule {
	if( [_rules containsObject:rule] ) return;
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _ruleMatched: ) name:MVChatUserWatchRuleMatchedNotification object:rule];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _ruleUserRemoved: ) name:MVChatUserWatchRuleRemovedMatchedUserNotification object:rule];
	[_rules addObject:rule];
}

- (void) removeWatchRule:(MVChatUserWatchRule *) rule {
	if( ! [_rules containsObject:rule] ) return;
	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatUserWatchRuleMatchedNotification object:rule];
	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatUserWatchRuleRemovedMatchedUserNotification object:rule];
	[_rules removeObject:rule];
}

#pragma mark -

- (NSImage *) picture {
	if( _picture )
		return _picture;
	if( _person )
		return [[NSImage alloc] initWithData:[_person imageData]];
	return nil;
}

#pragma mark -

- (NSString *) compositeName {
	NSString *firstName = [self firstName];
	NSString *lastName = [self lastName];

	if( ! [firstName length] && [lastName length] )
		return lastName;
	if( [firstName length] && ! [lastName length] )
		return firstName;
	if( [firstName length] && [lastName length] )
		return [NSString stringWithFormat:@"%@ %@", firstName, lastName];

	firstName = [self givenNickname];
	if( [firstName length] )
		return firstName;

	return [[self activeUser] nickname];
}

- (NSString *) firstName {
	if( _firstName ) return _firstName;
	if( _person ) return [_person valueForProperty:kABFirstNameProperty];
	return nil;
}

- (NSString *) lastName {
	if( _lastName ) return _lastName;
	if( _person ) return [_person valueForProperty:kABLastNameProperty];
	return nil;
}

- (NSString *) primaryEmail {
	if( _primaryEmail ) return _primaryEmail;

	if( _person ) {
		ABMultiValue *value = [_person valueForProperty:kABEmailProperty];
		return [value valueAtIndex:[value indexForIdentifier:[value primaryIdentifier]]];
	}

	return nil;
}

- (NSString *) givenNickname {
	if( _givenNickname ) return _givenNickname;
	if( _person ) return [_person valueForProperty:kABNicknameProperty];
	return nil;
}

#pragma mark -

@synthesize addressBookPersonRecord = _person;

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
	NSUInteger b1 = 0, b2 = 0;

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
	NSString *server1 = [[self activeUser] serverAddress];
	NSString *server2 = [[buddy activeUser] serverAddress];
	NSComparisonResult ret = [server1 caseInsensitiveCompare:server2];
	return ( ret != NSOrderedSame ? ret : [self nicknameCompare:buddy] );
}

- (NSComparisonResult) nicknameCompare:(JVBuddy *) buddy {
	NSString *name1 = [[self activeUser] nickname];
	NSString *name2 = [[buddy activeUser] nickname];
	return [name1 caseInsensitiveCompare:name2];
}
@end

#pragma mark -

@implementation JVBuddy (Private)
- (void) _addUser:(MVChatUser *) user {
	if( [_users containsObject:user] )
		return;

	BOOL cameOnline = ! [_users count];
	[_users addObject:user];

	if( [self status] != MVChatUserAvailableStatus && [self status] != MVChatUserAwayStatus )
		[self setActiveUser:user];

	[[NSNotificationCenter chatCenter] postNotificationName:JVBuddyUserCameOnlineNotification object:self userInfo:@{@"user": user}];

	if( cameOnline )
		[[NSNotificationCenter chatCenter] postNotificationName:JVBuddyCameOnlineNotification object:self userInfo:nil];
}

- (void) _removeUser:(MVChatUser *) user {
	if( ! [_users containsObject:user] )
		return;

	[_users removeObject:user];

	if( [[self activeUser] isEqualToChatUser:user] )
		[self setActiveUser:[_users anyObject]];

	[[NSNotificationCenter chatCenter] postNotificationName:JVBuddyUserWentOfflineNotification object:self userInfo:@{@"user": user}];

	if( ! [_users count] )
		[[NSNotificationCenter chatCenter] postNotificationName:JVBuddyWentOfflineNotification object:self userInfo:nil];
}

- (void) _buddyIdleUpdate:(NSNotification *) notification {
	MVChatUser *user = [notification object];
	NSNotification *note = [NSNotification notificationWithName:JVBuddyUserIdleTimeUpdatedNotification object:self userInfo:@{@"user": user}];
	[[NSNotificationQueue defaultQueue] enqueueNotification:note postingStyle:NSPostASAP coalesceMask:( NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender ) forModes:nil];
}

- (void) _buddyStatusChanged:(NSNotification *) notification {
	MVChatUser *user = [notification object];

	switch( [user status] ) {
		case MVChatUserAvailableStatus:
		case MVChatUserAwayStatus:
			[self _addUser:user];
			break;
		case MVChatUserOfflineStatus:
		case MVChatUserDetachedStatus:
			[self _removeUser:user];
		default: break;
	}

	[[NSNotificationCenter chatCenter] postNotificationName:JVBuddyUserStatusChangedNotification object:self userInfo:@{@"user": user}];
}

- (void) _registerWithConnection:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	[self registerWithConnection:connection];
}

- (void) _disconnected:(NSNotification *) notification {
	MVChatConnection *connection = [notification object];
	for( MVChatUser *user in [_users copy])
		if( [[user connection] isEqual:connection] )
			[self _removeUser:user];
}

- (void) _ruleMatched:(NSNotification *) notification {
	MVChatUser *user = [notification userInfo][@"user"];

	if( [user status] == MVChatUserAvailableStatus || [user status] == MVChatUserAwayStatus )
		[self _addUser:user];

	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _buddyIdleUpdate: ) name:MVChatUserIdleTimeUpdatedNotification object:user];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( _buddyStatusChanged: ) name:MVChatUserStatusChangedNotification object:user];
}

- (void) _ruleUserRemoved:(NSNotification *) notification {
	MVChatUser *user = [notification userInfo][@"user"];

	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatUserIdleTimeUpdatedNotification object:user];
	[[NSNotificationCenter chatCenter] removeObserver:self name:MVChatUserStatusChangedNotification object:user];

	[self _removeUser:user];
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
