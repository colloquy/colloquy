#import "MVChatConnection.h"
#import "MVChatConnectionPrivate.h"
#import "MVChatRoom.h"
#import "MVChatUser.h"
#import "MVUtilities.h"

#import "NSStringAdditions.h"
#import "NSDataAdditions.h"
#import "NSNotificationAdditions.h"

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

- (id) init {
	if( ( self = [super init] ) ) {
		_attributes = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:2];
		_memberUsers = [[NSMutableSet allocWithZone:nil] initWithCapacity:100];
		_bannedUsers = [[NSMutableSet allocWithZone:nil] initWithCapacity:5];
		_modeAttributes = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:2];
		_memberModes = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:100];
		_encoding = NSUTF8StringEncoding;
	}

	return self;
}

- (void) release {
	if( ! _releasing && ( [self retainCount] - 1 ) == 1 ) {
		_releasing = YES;
		[[self connection] _removeJoinedRoom:self];
	}

	[super release];
}

- (void) dealloc {
	[_name release];
	[_uniqueIdentifier release];
	[_dateJoined release];
	[_dateParted release];
	[_topic release];
	[_topicAuthor release];
	[_dateTopicChanged release];
	[_attributes release];
	[_memberUsers release];
	[_bannedUsers release];
	[_modeAttributes release];
	[_memberModes release];

	_connection = nil; // connection isn't retained, prevents circular retain
	_name = nil;
	_uniqueIdentifier = nil;
	_dateJoined = nil;
	_dateParted = nil;
	_topic = nil;
	_topicAuthor = nil;
	_dateTopicChanged = nil;
	_attributes = nil;
	_memberUsers = nil;
	_bannedUsers = nil;
	_modeAttributes = nil;
	_memberModes = nil;

	[super dealloc];
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

- (unsigned) hash {
	if( ! _hash ) _hash = ( [[self connection] hash] ^ [[self uniqueIdentifier] hash] );
	return _hash;
}

#pragma mark -

- (NSComparisonResult) compare:(MVChatRoom *) otherRoom {
	return [[self name] compare:[otherRoom name]];
}

- (NSComparisonResult) compareByUserCount:(MVChatRoom *) otherRoom {
	unsigned long count1 = [[self memberUsers] count];
	unsigned long count2 = [[otherRoom memberUsers] count];
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
	return [self name];
}

- (id) uniqueIdentifier {
	return _uniqueIdentifier;
}

#pragma mark -

- (void) join {
	NSString *passphrase = nil;
	if( [self supportedModes] & MVChatRoomPassphraseToJoinMode )
		passphrase = [self attributeForMode:MVChatRoomPassphraseToJoinMode];
	[[self connection] joinChatRoomNamed:[self name] withPassphrase:passphrase];
}

- (void) part {
	[self partWithReason:nil];
}

- (void) partWithReason:(MVChatString *) reason {
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
	[self sendMessage:message withEncoding:encoding withAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:action] forKey:@"action"]];
}

- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding withAttributes:(NSDictionary *) attributes {
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

- (void) setTopic:(MVChatString *) topic {
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
	} return nil;
}

- (BOOL) hasAttributeForKey:(NSString *) key {
	@synchronized( _attributes ) {
		return ( [_attributes objectForKey:key] ? YES : NO );
	} return NO;
}

- (id) attributeForKey:(NSString *) key {
	@synchronized( _attributes ) {
		return [_attributes objectForKey:key];
	} return nil;
}

- (void) setAttribute:(id) attribute forKey:(id) key {
	NSParameterAssert( key != nil );
	@synchronized( _attributes ) {
		if( attribute ) [_attributes setObject:attribute forKey:key];
		else [_attributes removeObjectForKey:key];
	}

	NSDictionary *info = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:key, @"attribute", nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatRoomAttributeUpdatedNotification object:self userInfo:info];
	[info release];
}

#pragma mark -

- (unsigned long) supportedModes {
// subclass this method, if needed
	return 0;
}

#pragma mark -

- (unsigned long) modes {
	return _modes;
}

- (id) attributeForMode:(MVChatRoomMode) mode {
	NSParameterAssert( [self supportedModes] & mode );
	@synchronized( _modeAttributes ) {
		return [_modeAttributes objectForKey:[NSNumber numberWithUnsignedInt:mode]];
	} return nil;
}

#pragma mark -

- (void) setModes:(unsigned long) newModes {
	NSParameterAssert( [self supportedModes] & newModes );

	unsigned long curModes = [self modes];
	unsigned long diffModes = ( curModes ^ newModes );

	unsigned i = 0;
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

- (void) setMode:(MVChatRoomMode) mode withAttribute:(id) attribute {
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
	} return nil;
}

- (NSSet *) memberUsersWithModes:(unsigned long) newModes {
	NSMutableSet *users = [[NSMutableSet allocWithZone:nil] init];

	@synchronized( _memberUsers ) {
		NSEnumerator *enumerator = [_memberUsers objectEnumerator];
		MVChatUser *user = nil;
		while( ( user = [enumerator nextObject] ) )
			if( [self modesForMemberUser:user] & newModes )
				[users addObject:user];
	}

	return [users autorelease];
}

- (NSSet *) memberUsersWithNickname:(NSString *) nickname {
	NSMutableSet *users = [[NSMutableSet allocWithZone:nil] init];

	@synchronized( _memberUsers ) {
		NSEnumerator *enumerator = [_memberUsers objectEnumerator];
		MVChatUser *user = nil;
		while( ( user = [enumerator nextObject] ) )
			if( [[user nickname] isEqualToString:nickname] )
				[users addObject:user];
	}

	return [users autorelease];
}

- (NSSet *) memberUsersWithFingerprint:(NSString *) fingerprint {
	NSMutableSet *users = [[NSMutableSet allocWithZone:nil] init];

	@synchronized( _memberUsers ) {
		NSEnumerator *enumerator = [_memberUsers objectEnumerator];
		MVChatUser *user = nil;
		while( ( user = [enumerator nextObject] ) )
			if( [[user fingerprint] isEqualToString:fingerprint] )
				[users addObject:user];
	}

	return [users autorelease];
}

- (MVChatUser *) memberUserWithUniqueIdentifier:(id) identifier {
	@synchronized( _memberUsers ) {
		MVChatUser *user = nil;
		NSEnumerator *enumerator = [_memberUsers objectEnumerator];
		while( ( user = [enumerator nextObject] ) )
			if( [[user uniqueIdentifier] isEqual:identifier] )
				return user;
	}

	return nil;
}

- (BOOL) hasUser:(MVChatUser *) user {
	NSParameterAssert( user != nil );
	@synchronized( _memberUsers ) {
		return [_memberUsers containsObject:user];
	} return NO;
}

#pragma mark -

- (void) kickOutMemberUser:(MVChatUser *) user forReason:(MVChatString *) reason {
	NSParameterAssert( user != nil );
// subclass this method, call super first
}

#pragma mark -

- (NSSet *) bannedUsers {
	@synchronized( _bannedUsers ) {
		return [NSSet setWithSet:_bannedUsers];
	} return nil;
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

- (unsigned long) supportedMemberUserModes {
// subclass this method, if needed
	return 0;
}

#pragma mark -

- (unsigned long) modesForMemberUser:(MVChatUser *) user {
	NSParameterAssert( user != nil );
	@synchronized( _memberModes ) {
		return [[_memberModes objectForKey:[user uniqueIdentifier]] unsignedLongValue];
	} return 0;
}

#pragma mark -

- (void) setModes:(unsigned long) newModes forMemberUser:(MVChatUser *) user {
	NSParameterAssert( user != nil );
	NSParameterAssert( [self supportedMemberUserModes] & newModes );

	unsigned long curModes = [self modesForMemberUser:user];
	unsigned long diffModes = ( curModes ^ newModes );

	unsigned i = 0;
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

#pragma mark -

- (NSString *) description {
	return [self name];
}
@end

#pragma mark -

@implementation MVChatRoom (MVChatRoomPrivate)
- (void) _addMemberUser:(MVChatUser *) user {
	@synchronized( _memberUsers ) {
		[_memberUsers addObject:user];
	}
}

- (void) _removeMemberUser:(MVChatUser *) user {
	@synchronized( _memberModes ) {
		[_memberModes removeObjectForKey:[user uniqueIdentifier]];
	} @synchronized( _memberUsers ) {
		[_memberUsers removeObject:user];
	}
}

- (void) _clearMemberUsers {
	@synchronized( _memberModes ) {
		[_memberModes removeAllObjects];
	} @synchronized( _memberUsers ) {
		[_memberUsers removeAllObjects];
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

- (void) _setModes:(unsigned long) newModes forMemberUser:(MVChatUser *) user {
	@synchronized( _memberModes ) {
		[_memberModes setObject:[NSNumber numberWithUnsignedLong:newModes] forKey:[user uniqueIdentifier]];
	}
}

- (void) _setMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user {
	@synchronized( _memberModes ) {
		unsigned long newModes = ( [[_memberModes objectForKey:[user uniqueIdentifier]] unsignedLongValue] | mode );
		[_memberModes setObject:[NSNumber numberWithUnsignedLong:newModes] forKey:[user uniqueIdentifier]];
	}
}

- (void) _removeMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user {
	@synchronized( _memberModes ) {
		unsigned long newModes = ( [[_memberModes objectForKey:[user uniqueIdentifier]] unsignedLongValue] & ~mode );
		[_memberModes setObject:[NSNumber numberWithUnsignedLong:newModes] forKey:[user uniqueIdentifier]];
	}
}

- (void) _clearModes {
	@synchronized( _modeAttributes ) {
		_modes = 0;
		[_modeAttributes removeAllObjects];
	}
}

- (void) _setMode:(MVChatRoomMode) mode withAttribute:(id) attribute {
	_modes |= mode;
	@synchronized( _modeAttributes ) {
		if( attribute ) [_modeAttributes setObject:attribute forKey:[NSNumber numberWithUnsignedLong:mode]];
		else [_modeAttributes removeObjectForKey:[NSNumber numberWithUnsignedLong:mode]];
	}
}

- (void) _removeMode:(MVChatRoomMode) mode {
	@synchronized( _modeAttributes ) {
		_modes &= ~mode;
		[_modeAttributes removeObjectForKey:[NSNumber numberWithUnsignedLong:mode]];
	}
}

- (void) _setDateJoined:(NSDate *) date {
	MVSafeCopyAssign( &_dateJoined, date );
}

- (void) _setDateParted:(NSDate *) date {
	MVSafeCopyAssign( &_dateParted, date );
}

- (void) _setTopic:(NSData *) newTopic {
	MVSafeCopyAssign( &_topic, newTopic );
}

- (void) _setTopicAuthor:(MVChatUser *) author {
	MVSafeRetainAssign( &_topicAuthor, author );
}

- (void) _setTopicDate:(NSDate *) date {
	MVSafeCopyAssign( &_dateTopicChanged, date );
}

- (void) _updateMemberUser:(MVChatUser *) user fromOldUniqueIdentifier:(id) identifier {
	@synchronized( _memberModes ) {
		NSNumber *userModes = [[_memberModes objectForKey:identifier] retain];
		if( ! userModes ) return;
		[_memberModes removeObjectForKey:identifier];
		[_memberModes setObject:userModes forKey:[user uniqueIdentifier]];
		[userModes release];
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
	return [[[NSUniqueIDSpecifier allocWithZone:nil] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"joinedChatRoomsArray" uniqueID:[self scriptUniqueIdentifier]] autorelease];
}

#pragma mark -

- (NSArray *) memberUsersArray {
	return [[self memberUsers] allObjects];
}

- (MVChatUser *) valueInMemberUsersArrayAtIndex:(unsigned) index {
	return [[self memberUsersArray] objectAtIndex:index];
}

- (MVChatUser *) valueInMemberUsersArrayWithUniqueID:(id) identifier {
	return [self memberUserWithUniqueIdentifier:identifier];
}

- (MVChatUser *) valueInMemberUsersArrayWithName:(NSString *) memberName {
	NSEnumerator *enumerator = [[self memberUsers] objectEnumerator];
	MVChatUser *user = nil;

	while( ( user = [enumerator nextObject] ) )
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
#endif
