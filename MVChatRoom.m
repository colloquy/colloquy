#import "MVChatConnection.h"
#import "MVChatRoom.h"
#import "MVChatUser.h"

#import "NSStringAdditions.h"
#import "NSDataAdditions.h"
#import "NSNotificationAdditions.h"

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

NSString *MVChatRoomGotMessageNotification = @"MVChatRoomGotMessageNotification";
NSString *MVChatRoomTopicChangedNotification = @"MVChatRoomTopicChangedNotification";
NSString *MVChatRoomModesChangedNotification = @"MVChatRoomModesChangedNotification";
NSString *MVChatRoomAttributeUpdatedNotification = @"MVChatRoomAttributeUpdatedNotification";

@implementation MVChatRoom
+ (void) initialize {
	[super initialize];
	static BOOL tooLate = NO;
	if( ! tooLate ) {
		[[NSScriptCoercionHandler sharedCoercionHandler] registerCoercer:[self class] selector:@selector( coerceChatRoom:toString: ) toConvertFromClass:[MVChatRoom class] toClass:[NSString class]];
		tooLate = YES;
	}
}

+ (id) coerceChatRoom:(id) value toString:(Class) class {
	return [value name];
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_connection = nil;
		_name = nil;
		_uniqueIdentifier = nil;
		_dateJoined = nil;
		_dateParted = nil;
		_topicData = nil;
		_topicAuthor = nil;
		_dateTopicChanged = nil;
		_attributes = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:2];
		_memberUsers = [[NSMutableSet allocWithZone:nil] initWithCapacity:100];
		_bannedUsers = [[NSMutableSet allocWithZone:nil] initWithCapacity:5];
		_modeAttributes = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:2];
		_memberModes = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:100];
		_encoding = NSUTF8StringEncoding;
		_modes = 0;
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_name release];
	[_uniqueIdentifier release];
	[_dateJoined release];
	[_dateParted release];
	[_topicData release];
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
	_topicData = nil;
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
	return ( [[self uniqueIdentifier] hash] ^ [[self connection] hash] ^ [[self uniqueIdentifier] hash] );
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
	NSString *url = [NSString stringWithFormat:@"%@://%@/%@", [[self connection] urlScheme], [[[self connection] server] stringByEncodingIllegalURLCharacters], [[self name] stringByEncodingIllegalURLCharacters]];
	if( url ) return [NSURL URLWithString:url];
	return nil;
}

- (NSString *) name {
	return [[_name retain] autorelease];
}

- (NSString *) displayName {
	return [self name];
}

- (id) uniqueIdentifier {
	return [[_uniqueIdentifier retain] autorelease];
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

- (void) partWithReason:(NSAttributedString *) reason {
// subclass this method, don't call super
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (BOOL) isJoined {
	return ( [self dateJoined] && ! [self dateParted] );
}

- (NSDate *) dateJoined {
	return [[_dateJoined retain] autorelease];
}

- (NSDate *) dateParted {
	return [[_dateParted retain] autorelease];
}

#pragma mark -

- (NSStringEncoding) encoding {
	return _encoding;
}

- (void) setEncoding:(NSStringEncoding) encoding {
	_encoding = encoding;
}

#pragma mark -

- (void) sendMessage:(NSAttributedString *) message asAction:(BOOL) action {
	[self sendMessage:message withEncoding:[self encoding] asAction:action];
}

- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action {
// subclass this method, don't call super
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (void) sendSubcodeRequest:(NSString *) command withArguments:(NSString *) arguments {
// subclass this method, if needed
}

- (void) sendSubcodeReply:(NSString *) command withArguments:(NSString *) arguments {
// subclass this method, if needed
}

#pragma mark -

- (NSData *) topic {
	return [[_topicData retain] autorelease];
}

- (MVChatUser *) topicAuthor {
	return [[_topicAuthor retain] autorelease];
}

- (NSDate *) dateTopicChanged {
	return [[_dateTopicChanged retain] autorelease];
}

- (void) setTopic:(NSAttributedString *) topic {
// subclass this method, if needed
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
	NSParameterAssert( [[self supportedAttributes] containsObject:key] );
	@synchronized( _attributes ) {
		return ( [_attributes objectForKey:key] ? YES : NO );
	} return NO;
}

- (id) attributeForKey:(NSString *) key {
	NSParameterAssert( [[self supportedAttributes] containsObject:key] );
	@synchronized( _attributes ) {
		return [[[_attributes objectForKey:key] retain] autorelease];
	} return nil;
}

- (void) setAttribute:(id) attribute forKey:(id) key {
	NSParameterAssert( key != nil );
	@synchronized( _attributes ) {
		if( attribute ) [_attributes setObject:attribute forKey:key];
		else [_attributes removeObjectForKey:key];
	}
	
	NSDictionary *info = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:key, @"attribute", nil];
	NSNotification *note = [NSNotification notificationWithName:MVChatRoomAttributeUpdatedNotification object:self userInfo:info];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
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
		return [[[_modeAttributes objectForKey:[NSNumber numberWithUnsignedInt:mode]] retain] autorelease];
	} return nil;
}

#pragma mark -

- (void) setModes:(unsigned long) modes {
	NSParameterAssert( [self supportedModes] & modes );

	unsigned long curModes = [self modes];
	unsigned long diffModes = ( curModes ^ modes );

	unsigned i = 0;
	for( i = 0; i <= 8; i++ ) {
		if( ( 1 << i ) & diffModes ) {
			if( ( 1 << i ) & modes ) [self setMode:( 1 << i ) withAttribute:nil];
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

- (NSSet *) memberUsers {
	@synchronized( _memberUsers ) {
		return [NSSet setWithSet:_memberUsers];
	} return nil;
}

- (NSSet *) memberUsersWithModes:(unsigned long) modes {
	NSMutableSet *users = [[NSMutableSet allocWithZone:nil] init];

	@synchronized( _memberUsers ) {
		NSEnumerator *enumerator = [_memberUsers objectEnumerator];
		MVChatUser *user = nil;
		while( ( user = [enumerator nextObject] ) )
			if( [self modesForMemberUser:user] & modes )
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
				return [[user retain] autorelease];
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

- (void) kickOutMemberUser:(MVChatUser *) user forReason:(NSAttributedString *) reason {
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

- (void) setModes:(unsigned long) modes forMemberUser:(MVChatUser *) user {
	NSParameterAssert( user != nil );
	NSParameterAssert( [self supportedMemberUserModes] & modes );

	unsigned long curModes = [self modesForMemberUser:user];
	unsigned long diffModes = ( curModes ^ modes );

	unsigned i = 0;
	for( i = 0; i <= 8; i++ ) {
		if( ( 1 << i ) & diffModes ) {
			if( ( 1 << i ) & modes ) [self setMode:( 1 << i ) forMemberUser:user];
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

- (void) _setMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user {
	@synchronized( _memberModes ) {
		unsigned long modes = ( [[_memberModes objectForKey:[user uniqueIdentifier]] unsignedLongValue] | mode );
		[_memberModes setObject:[NSNumber numberWithUnsignedLong:modes] forKey:[user uniqueIdentifier]];
	}
}

- (void) _removeMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user {
	@synchronized( _memberModes ) {
		unsigned long modes = ( [[_memberModes objectForKey:[user uniqueIdentifier]] unsignedLongValue] & ~mode );
		[_memberModes setObject:[NSNumber numberWithUnsignedLong:modes] forKey:[user uniqueIdentifier]];
	}
}

- (void) _clearModes {
	_modes = 0;
	@synchronized( _modeAttributes ) {
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
	_modes &= ~mode;
	@synchronized( _modeAttributes ) {
		[_modeAttributes removeObjectForKey:[NSNumber numberWithUnsignedLong:mode]];
	}
}

- (void) _setDateJoined:(NSDate *) date {
	[_dateJoined autorelease];
	_dateJoined = [date copyWithZone:nil];
}

- (void) _setDateParted:(NSDate *) date {
	[_dateParted autorelease];
	_dateParted = [date copyWithZone:nil];
}

- (void) _setTopic:(NSData *) topic byAuthor:(MVChatUser *) author withDate:(NSDate *) date {
	[_topicData autorelease];
	_topicData = [topic copyWithZone:nil];

	[_topicAuthor autorelease];
	_topicAuthor = [author retain];

	[_dateTopicChanged autorelease];
	_dateTopicChanged = [date copyWithZone:nil];

	NSNotification *note = [NSNotification notificationWithName:MVChatRoomTopicChangedNotification object:self userInfo:nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

- (void) _updateMemberUser:(MVChatUser *) user fromOldUniqueIdentifier:(id) identifier {
	NSNumber *modes = [[[_memberModes objectForKey:identifier] retain] autorelease];
	if( ! modes ) return;
	@synchronized( _memberModes ) {
		[_memberModes removeObjectForKey:identifier];
		[_memberModes setObject:modes forKey:[user uniqueIdentifier]];
	}
}
@end

#pragma mark -

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

- (MVChatUser *) valueInMemberUsersArrayWithName:(NSString *) name {
	NSEnumerator *enumerator = [[self memberUsers] objectEnumerator];
	MVChatUser *user = nil;

	while( ( user = [enumerator nextObject] ) )
		if( [[user nickname] caseInsensitiveCompare:name] == NSOrderedSame )
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

- (void) setScriptTypedEncoding:(unsigned long) encoding {
	[self setEncoding:[NSString stringEncodingFromScriptTypedEncoding:encoding]];
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