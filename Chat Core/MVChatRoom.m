#import "MVChatConnection.h"
#import "MVChatConnectionPrivate.h"
#import "MVChatRoom.h"
#import "MVChatUser.h"
#import "MVUtilities.h"

#import "NSStringAdditions.h"
#import "NSDataAdditions.h"
#import "NSNotificationAdditions.h"

NS_ASSUME_NONNULL_BEGIN

NSString *MVChatRoomMemberQuietedFeature = @"MVChatRoomMemberQuietedFeature";
NSString *MVChatRoomMemberVoicedFeature = @"MVChatRoomMemberVoicedFeature";
NSString *MVChatRoomMemberHalfOperatorFeature = @"MVChatRoomMemberHalfOperatorFeature";
NSString *MVChatRoomMemberOperatorFeature = @"MVChatRoomMemberOperatorFeature";
NSString *MVChatRoomMemberAdministratorFeature = @"MVChatRoomMemberAdministratorFeature";
NSString *MVChatRoomMemberFounderFeature = @"MVChatRoomMemberFounderFeature";

NSString *MVChatRoomJoinedNotification = @"MVChatRoomJoinedNotification";
NSString *MVChatRoomPartedNotification = @"MVChatRoomPartedNotification";
NSString *MVChatRoomKickedNotification = @"MVChatRoomKickedNotification";
NSString *MVChatRoomInvitedNotification = @"MVChatRoomInvitedNotification";

NSString *MVChatRoomMemberUsersSyncedNotification = @"MVChatRoomMemberUsersSyncedNotification";
NSString *MVChatRoomBannedUsersSyncedNotification = @"MVChatRoomBannedUsersSyncedNotification";

NSString *MVChatRoomUserJoinedNotification = @"MVChatRoomUserJoinedNotification";
NSString *MVChatRoomUserPartedNotification = @"MVChatRoomUserPartedNotification";
NSString *MVChatRoomUserKickedNotification = @"MVChatRoomUserKickedNotification";
NSString *MVChatRoomUserBannedNotification = @"MVChatRoomUserBannedNotification";
NSString *MVChatRoomUserBanRemovedNotification = @"MVChatRoomUserBanRemovedNotification";
NSString *MVChatRoomUserModeChangedNotification = @"MVChatRoomUserModeChangedNotification";
NSString *MVChatRoomUserBrickedNotification = @"MVChatRoomUserBrickedNotification";

NSString *MVChatRoomGotMessageNotification = @"MVChatRoomGotMessageNotification";
NSString *MVChatRoomTopicChangedNotification = @"MVChatRoomTopicChangedNotification";
NSString *MVChatRoomModesChangedNotification = @"MVChatRoomModesChangedNotification";
NSString *MVChatRoomAttributeUpdatedNotification = @"MVChatRoomAttributeUpdatedNotification";

@implementation MVChatRoom
#if ENABLE(SCRIPTING)
+ (void) initialize {
	[super initialize];
	static BOOL tooLate = NO;
	if( ! tooLate ) {
		[[NSScriptCoercionHandler sharedCoercionHandler] registerCoercer:[self class] selector:@selector( coerceChatRoom:toString: ) toConvertFromClass:[MVChatRoom class] toClass:[NSString class]];
		tooLate = YES;
	}
}

+ (id) coerceChatRoom:(id) value toString:(Class) class {
	return [(MVChatRoom *)value name];
}
#endif

#pragma mark -

- (instancetype) init {
	if( ( self = [super init] ) ) {
		_attributes = [[NSMutableDictionary alloc] initWithCapacity:2];
		_memberUsers = [[NSMutableSet alloc] initWithCapacity:100];
		_bannedUsers = [[NSMutableSet alloc] initWithCapacity:5];
		_modeAttributes = [[NSMutableDictionary alloc] initWithCapacity:2];
		_memberModes = [[NSMutableDictionary alloc] initWithCapacity:100];
		_disciplineMemberModes = [[NSMutableDictionary alloc] initWithCapacity:100];
		_encoding = NSUTF8StringEncoding;
	}

	return self;
}

- (void) dealloc {
	__strong MVChatConnection *connection = _connection;
	[connection _removeKnownRoom:self];
	[connection _removeJoinedRoom:self];
}

#pragma mark -

- (MVChatConnection *) connection {
	return _connection;
}

#pragma mark -

- (BOOL) isEqual:(id) object {
	if( object == self ) return YES;
	if( ! object || ! [object isKindOfClass:[self class]] ) return NO;
	return [self isEqualToChatRoom:object];
}

- (BOOL) isEqualToChatRoom:(MVChatRoom *) anotherRoom {
	if( ! anotherRoom ) return NO;
	if( anotherRoom == self ) return YES;
	if( ! [[self connection] isEqual:[anotherRoom connection]] )
		return NO;
	if( ! [[self uniqueIdentifier] isEqual:[anotherRoom uniqueIdentifier]] )
		return NO;
	return YES;
}

- (NSUInteger) hash {
	if( ! _hash ) _hash = ( [[self connection] hash] ^ [[self uniqueIdentifier] hash] );
	return _hash;
}

#pragma mark -

- (NSComparisonResult) compare:(MVChatRoom *) otherRoom {
	return [[self name] compare:[otherRoom name]];
}

- (NSComparisonResult) compareByUserCount:(MVChatRoom *) otherRoom {
	NSUInteger count1 = [[self memberUsers] count];
	NSUInteger count2 = [[otherRoom memberUsers] count];
	return ( count1 == count2 ? NSOrderedSame : ( count1 > count2 ? NSOrderedAscending : NSOrderedDescending ) );
}

#pragma mark -

- (NSURL *) url {
	NSString *urlString = [NSString stringWithFormat:@"%@://%@/%@", [[self connection] urlScheme], [[[self connection] server] stringByEncodingIllegalURLCharacters], [[self name] stringByEncodingIllegalURLCharacters]];
	if( urlString ) return [NSURL URLWithString:urlString];
	return nil;
}

- (NSString *) name {
	return _name;
}

- (NSString *) displayName {
	__strong MVChatConnection *connection = _connection;
	return connection ? [connection displayNameForChatRoomNamed:[self name]] : [self name];
}

- (id) uniqueIdentifier {
	return _uniqueIdentifier;
}

#pragma mark -

- (void) join {
	if( [self isJoined] ) return;

	NSString *passphrase = nil;
	if( [self supportedModes] & MVChatRoomPassphraseToJoinMode )
		passphrase = [self attributeForMode:MVChatRoomPassphraseToJoinMode];

	if (passphrase.length)
		[[self connection] joinChatRoomNamed:[self name] withPassphrase:passphrase];
	else [[self connection] joinChatRoomNamed:[self name]];
}

- (void) part {
	[self partWithReason:nil];
}

- (void) partWithReason:(MVChatString * __nullable) reason {
// subclass this method, don't call super
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (BOOL) isJoined {
	return ( [self dateJoined] && ! [self dateParted] );
}

- (NSDate *) dateJoined {
	return _dateJoined;
}

- (NSDate *) dateParted {
	return _dateParted;
}

- (NSDate *) mostRecentUserActivity {
	return _mostRecentUserActivity;
}

- (void) requestRecentActivity {
	// subclass this method, don't call super
}

- (void) persistLastActivityDate {
	// subclass this method, don't call super
}

#pragma mark -

- (NSStringEncoding) encoding {
	return _encoding;
}

- (void) setEncoding:(NSStringEncoding) encoding {
	_encoding = encoding;
}

#pragma mark -

- (void) sendMessage:(MVChatString *) message asAction:(BOOL) action {
	[self sendMessage:message withEncoding:[self encoding] asAction:action];
}

- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action {
	[self sendMessage:message withEncoding:encoding withAttributes:@{ @"action": @(action) }];
}

- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding withAttributes:(NSDictionary *) attributes {
	// subclass this method, don't call super
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (void) sendCommand:(NSString *) command withArguments:(MVChatString *) arguments {
	[self sendCommand:command withArguments:arguments withEncoding:[self encoding]];
}

- (void) sendCommand:(NSString *) command withArguments:(MVChatString *) arguments withEncoding:(NSStringEncoding) encoding {
	// subclass this method, don't call super
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (void) sendSubcodeRequest:(NSString *) command withArguments:(id) arguments {
// subclass this method, if needed
}

- (void) sendSubcodeReply:(NSString *) command withArguments:(id) arguments {
// subclass this method, if needed
}

#pragma mark -

- (NSData *) topic {
	return _topic;
}

- (void) changeTopic:(MVChatString *) topic {
// subclass this method, if needed
}

- (MVChatUser *) topicAuthor {
	return _topicAuthor;
}

- (NSDate *) dateTopicChanged {
	return _dateTopicChanged;
}

#pragma mark -

- (void) refreshAttributes {
// subclass this method, if needed
}

- (void) refreshAttributeForKey:(NSString *) key {
	NSParameterAssert( [[self supportedAttributes] containsObject:key] );
// subclass this method, call super first
}

#pragma mark -

- (NSSet *) supportedAttributes {
// subclass this method, if needed
	return nil;
}

#pragma mark -

- (NSDictionary *) attributes {
	@synchronized( _attributes ) {
		return [NSDictionary dictionaryWithDictionary:_attributes];
	}
}

- (BOOL) hasAttributeForKey:(NSString *) key {
	@synchronized( _attributes ) {
		return ( _attributes[key] ? YES : NO );
	}
}

- (id) attributeForKey:(NSString *) key {
	@synchronized( _attributes ) {
		return _attributes[key];
	}
}

- (void) setAttribute:(id) attribute forKey:(id) key {
	NSParameterAssert( key != nil );
	@synchronized( _attributes ) {
		if( attribute ) _attributes[key] = attribute;
		else [_attributes removeObjectForKey:key];
	}

	NSDictionary *info = @{ @"attribute": key };
	[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatRoomAttributeUpdatedNotification object:self userInfo:info];
}

#pragma mark -

- (NSUInteger) supportedModes {
// subclass this method, if needed
	return 0;
}

#pragma mark -

- (NSUInteger) modes {
	return _modes;
}

- (id) attributeForMode:(MVChatRoomMode) mode {
	NSParameterAssert( [self supportedModes] & mode );
	@synchronized( _modeAttributes ) {
		return _modeAttributes[@(mode)];
	}
}

#pragma mark -

- (void) setModes:(NSUInteger) newModes {
	NSParameterAssert( [self supportedModes] & newModes );

	NSUInteger curModes = [self modes];
	NSUInteger diffModes = ( curModes ^ newModes );

	NSUInteger i = 0;
	for( i = 0; i <= 8; i++ ) {
		if( ( 1 << i ) & diffModes ) {
			if( ( 1 << i ) & newModes ) [self setMode:( 1 << i ) withAttribute:nil];
			else [self removeMode:( 1 << i )];
		}
	}
}

- (void) setMode:(MVChatRoomMode) mode {
	[self setMode:mode withAttribute:nil];
}

- (void) setMode:(MVChatRoomMode) mode withAttribute:(id __nullable) attribute {
	NSParameterAssert( [self supportedModes] & mode );
// subclass this method, call super first
}

- (void) removeMode:(MVChatRoomMode) mode {
	NSParameterAssert( [self supportedModes] & mode );
// subclass this method, call super first
}

#pragma mark -

- (MVChatUser *) localMemberUser {
	return [[self connection] localUser];
}

- (NSSet *) memberUsers {
	@synchronized( _memberUsers ) {
		return [NSSet setWithSet:_memberUsers];
	}
}

- (NSSet *) memberUsersWithModes:(NSUInteger) newModes {
	NSMutableSet *users = [[NSMutableSet alloc] init];

	@synchronized( _memberUsers ) {
		for( MVChatUser *user in _memberUsers )
			if( [self modesForMemberUser:user] & newModes )
				[users addObject:user];
	}

	return users;
}

- (NSSet *) memberUsersWithNickname:(NSString *) nickname {
	NSMutableSet *users = [[NSMutableSet alloc] init];

	@synchronized( _memberUsers ) {
		for( MVChatUser *user in _memberUsers )
			if( [[user nickname] isEqualToString:nickname] )
				[users addObject:user];
	}

	return users;
}

- (NSSet *) memberUsersWithFingerprint:(NSString *) fingerprint {
	NSMutableSet *users = [[NSMutableSet alloc] init];

	@synchronized( _memberUsers ) {
		for( MVChatUser *user in _memberUsers )
			if( [[user fingerprint] isEqualToString:fingerprint] )
				[users addObject:user];
	}

	return users;
}

- (MVChatUser *) memberUserWithUniqueIdentifier:(id) identifier {
	@synchronized( _memberUsers ) {
		for( MVChatUser *user in _memberUsers )
			if( [[user uniqueIdentifier] isEqual:identifier] )
				return user;
	}

	return nil;
}

- (BOOL) hasUser:(MVChatUser *) user {
	NSParameterAssert( user != nil );
	@synchronized( _memberUsers ) {
		return [_memberUsers containsObject:user];
	}
}

#pragma mark -

- (void) kickOutMemberUser:(MVChatUser *) user forReason:(MVChatString * __nullable) reason {
	NSParameterAssert( user != nil );
// subclass this method, call super first
}

#pragma mark -

- (NSSet *) bannedUsers {
	@synchronized( _bannedUsers ) {
		return [NSSet setWithSet:_bannedUsers];
	}
}

- (void) addBanForUser:(MVChatUser *) user {
	NSParameterAssert( user != nil );
// subclass this method, call super first
}

- (void) removeBanForUser:(MVChatUser *) user {
	NSParameterAssert( user != nil );
// subclass this method, call super first
}

#pragma mark -

- (NSUInteger) supportedMemberUserModes {
// subclass this method, if needed
	return 0;
}

- (NSUInteger) supportedMemberDisciplineModes {
	// subclass this method, if needed
	return 0;
}

#pragma mark -

- (NSUInteger) modesForMemberUser:(MVChatUser *) user {
	NSParameterAssert( user != nil );
	@synchronized( _memberModes ) {
		return [_memberModes[[user uniqueIdentifier]] unsignedLongValue];
	}
}

- (NSUInteger) disciplineModesForMemberUser:(MVChatUser *) user {
	NSParameterAssert( user != nil );
	@synchronized( _disciplineMemberModes ) {
		return [_disciplineMemberModes[[user uniqueIdentifier]] unsignedLongValue];
	}
}

#pragma mark -

- (void) setModes:(NSUInteger) newModes forMemberUser:(MVChatUser *) user {
	NSParameterAssert( user != nil );
	NSParameterAssert( [self supportedMemberUserModes] & newModes );

	NSUInteger curModes = [self modesForMemberUser:user];
	NSUInteger diffModes = ( curModes ^ newModes );

	NSUInteger i = 0;
	for( i = 0; i <= 8; i++ ) {
		if( ( 1 << i ) & diffModes ) {
			if( ( 1 << i ) & newModes ) [self setMode:( 1 << i ) forMemberUser:user];
			else [self removeMode:( 1 << i ) forMemberUser:user];
		}
	}
}

- (void) setMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user {
	NSParameterAssert( user != nil );
	NSParameterAssert( [self supportedMemberUserModes] & mode );
// subclass this method, call super first
}

- (void) removeMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user {
	NSParameterAssert( user != nil );
	NSParameterAssert( [self supportedMemberUserModes] & mode );
// subclass this method, call super first
}

- (void) setDisciplineMode:(MVChatRoomMemberDisciplineMode) mode forMemberUser:(MVChatUser *) user {
	NSParameterAssert( user != nil );
	NSParameterAssert( [self supportedMemberDisciplineModes] & mode );
	// subclass this method, call super first
}

- (void) removeDisciplineMode:(MVChatRoomMemberDisciplineMode) mode forMemberUser:(MVChatUser *) user {
	NSParameterAssert( user != nil );
	NSParameterAssert( [self supportedMemberDisciplineModes] & mode );
	// subclass this method, call super first
}

#pragma mark -

- (NSString *) description {
	return [self name];
}
@end

#pragma mark -

@implementation MVChatRoom (MVChatRoomPrivate)
- (void) _connectionDestroyed {
	_connection = nil;
}

- (void) _addMemberUser:(MVChatUser *) user {
	@synchronized( _memberUsers ) {
		[_memberUsers addObject:user];
		user.roomCount++;
	}
}

- (void) _removeMemberUser:(MVChatUser *) user {
	@synchronized( _memberModes ) {
		[_memberModes removeObjectForKey:[user uniqueIdentifier]];
	} @synchronized( _memberUsers ) {
		[_memberUsers removeObject:user];
		user.roomCount--;
	} @synchronized( _disciplineMemberModes) {
		[_disciplineMemberModes removeObjectForKey:[user uniqueIdentifier]];
	}
}

- (void) _clearMemberUsers {
	@synchronized( _memberModes ) {
		[_memberModes removeAllObjects];
	} @synchronized( _memberUsers ) {
		for (MVChatUser *user in _memberUsers)
			user.roomCount--;
		[_memberUsers removeAllObjects];
	} @synchronized( _disciplineMemberModes) {
		[_disciplineMemberModes removeAllObjects];
	}
}

- (void) _clearBannedUsers {
	@synchronized( _bannedUsers ) {
		[_bannedUsers removeAllObjects];
	}
}

- (void) _addBanForUser:(MVChatUser *) user {
	@synchronized( _bannedUsers ) {
		[_bannedUsers addObject:user];
	}
}

- (void) _removeBanForUser:(MVChatUser *) user {
	@synchronized( _bannedUsers ) {
		[_bannedUsers removeObject:user];
	}
}

- (void) _setModes:(NSUInteger) newModes forMemberUser:(MVChatUser *) user {
	@synchronized( _memberModes ) {
		_memberModes[[user uniqueIdentifier]] = @(newModes);
	}
}

- (void) _setMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user {
	@synchronized( _memberModes ) {
		NSUInteger newModes = ( [_memberModes[[user uniqueIdentifier]] unsignedLongValue] | mode );
		_memberModes[[user uniqueIdentifier]] = @(newModes);
	}
}

- (void) _removeMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user {
	@synchronized( _memberModes ) {
		NSUInteger newModes = ( [_memberModes[[user uniqueIdentifier]] unsignedLongValue] & ~mode );
		_memberModes[[user uniqueIdentifier]] = @(newModes);
	}
}

- (void) _setDisciplineModes:(NSUInteger) modes forMemberUser:(MVChatUser *) user {
	@synchronized( _disciplineMemberModes ) {
		_disciplineMemberModes[[user uniqueIdentifier]] = @(modes);
	}
}

- (void) _setDisciplineMode:(MVChatRoomMemberDisciplineMode) mode forMemberUser:(MVChatUser *) user {
	@synchronized( _disciplineMemberModes ) {
		NSUInteger newModes = ( [_disciplineMemberModes[[user uniqueIdentifier]] unsignedLongValue] | mode );
		_disciplineMemberModes[[user uniqueIdentifier]] = @(newModes);
	}
}

- (void) _removeDisciplineMode:(MVChatRoomMemberDisciplineMode) mode forMemberUser:(MVChatUser *) user {
	@synchronized( _disciplineMemberModes ) {
		NSUInteger newModes = ( [_disciplineMemberModes[[user uniqueIdentifier]] unsignedLongValue] & ~mode );
		_disciplineMemberModes[[user uniqueIdentifier]] = @(newModes);
	}
}

- (void) _clearModes {
	@synchronized( _modeAttributes ) {
		_modes = 0;
		[_modeAttributes removeAllObjects];
	}
}

- (void) _setMode:(MVChatRoomMode) mode withAttribute:(id __nullable) attribute {
	_modes |= mode;
	@synchronized( _modeAttributes ) {
		if( attribute ) _modeAttributes[@(mode)] = attribute;
		else [_modeAttributes removeObjectForKey:@(mode)];
	}
}

- (void) _removeMode:(MVChatRoomMode) mode {
	@synchronized( _modeAttributes ) {
		_modes &= ~mode;
		[_modeAttributes removeObjectForKey:@(mode)];
	}
}

- (void) _setDateJoined:(NSDate * __nullable) date {
	MVSafeCopyAssign( _dateJoined, date );
	__strong MVChatConnection *connection = _connection;
	if (date) [connection _addJoinedRoom:self];
}

- (void) _setDateParted:(NSDate * __nullable) date {
	MVSafeCopyAssign( _dateParted, date );
	__strong MVChatConnection *connection = _connection;
	if (date) [connection _removeJoinedRoom:self];
}

- (void) _setTopic:(NSData *) newTopic {
	MVSafeCopyAssign( _topic, newTopic );
}

- (void) _setTopicAuthor:(MVChatUser *) author {
	MVSafeRetainAssign( _topicAuthor, author );
}

- (void) _setTopicDate:(NSDate *) date {
	MVSafeCopyAssign( _dateTopicChanged, date );
}

- (void) _updateMemberUser:(MVChatUser *) user fromOldUniqueIdentifier:(id) identifier {
	@synchronized( _memberModes ) {
		NSNumber *userModes = _memberModes[identifier];
		if( userModes ) {
			[_memberModes removeObjectForKey:identifier];
			_memberModes[[user uniqueIdentifier]] = userModes;
		}
	}

	@synchronized( _disciplineMemberModes ) {
		NSNumber *userModes = _disciplineMemberModes[identifier];
		if( userModes ) {
			[_disciplineMemberModes removeObjectForKey:identifier];
			_disciplineMemberModes[[user uniqueIdentifier]] = userModes;
		}
	}
}
@end

#pragma mark -

#if ENABLE(SCRIPTING)
@implementation MVChatRoom (MVChatRoomScripting)
- (NSString *) scriptUniqueIdentifier {
	if( [[self uniqueIdentifier] isKindOfClass:[NSString class]] )
		return [self uniqueIdentifier];

	if( [[self uniqueIdentifier] isKindOfClass:[NSData class]] )
		return [[self uniqueIdentifier] base64Encoding];

	return [[self uniqueIdentifier] description];
}

- (NSScriptObjectSpecifier *) objectSpecifier {
	id classDescription = [NSClassDescription classDescriptionForClass:[MVChatConnection class]];
	NSScriptObjectSpecifier *container = [[self connection] objectSpecifier];
	return [[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"joinedChatRoomsArray" uniqueID:[self scriptUniqueIdentifier]];
}

#pragma mark -

- (NSArray *) memberUsersArray {
	return [[self memberUsers] allObjects];
}

- (MVChatUser *) valueInMemberUsersArrayAtIndex:(NSUInteger) index {
	return [[self memberUsersArray] objectAtIndex:index];
}

- (MVChatUser *) valueInMemberUsersArrayWithUniqueID:(id) identifier {
	return [self memberUserWithUniqueIdentifier:identifier];
}

- (MVChatUser *) valueInMemberUsersArrayWithName:(NSString *) memberName {
	for( MVChatUser *user in [self memberUsers] )
		if( [[user nickname] isCaseInsensitiveEqualToString:memberName] )
			return user;

	return nil;
}

#pragma mark -

- (NSString *) urlString {
	return [[self url] absoluteString];
}

#pragma mark -

- (NSArray *) bannedUsersArray {
	return [[self bannedUsers] allObjects];
}

#pragma mark -

- (unsigned long) scriptTypedEncoding {
	return [NSString scriptTypedEncodingFromStringEncoding:[self encoding]];
}

- (void) setScriptTypedEncoding:(unsigned long) newEncoding {
	[self setEncoding:[NSString stringEncodingFromScriptTypedEncoding:newEncoding]];
}

NS_ASSUME_NONNULL_END

#pragma mark -

- (id) valueForUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The chat room id \"%@\" of connection id %@ doesn't have the \"%@\" property.", [self scriptUniqueIdentifier], [[self connection] uniqueIdentifier], key]];
		return nil;
	}

	return [super valueForUndefinedKey:key];
}

- (void) setValue:(id) value forUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The \"%@\" property of chat room id \"%@\" of connection id %@ is read only.", key, [self scriptUniqueIdentifier], [[self connection] uniqueIdentifier]]];
		return;
	}

	[super setValue:value forUndefinedKey:key];
}
@end

#else

NS_ASSUME_NONNULL_END

#endif
