#import "MVChatConnection.h"
#import "MVChatRoom.h"
#import "MVChatUser.h"

#import "NSStringAdditions.h"

NSString *MVChatRoomJoinedNotification = @"MVChatRoomJoinedNotification";
NSString *MVChatRoomPartedNotification = @"MVChatRoomPartedNotification";
NSString *MVChatRoomKickedNotification = @"MVChatRoomKickedNotification";
NSString *MVChatRoomInvitedNotification = @"MVChatRoomInvitedNotification";

NSString *MVChatRoomUserJoinedNotification = @"MVChatRoomUserJoinedNotification";
NSString *MVChatRoomUserPartedNotification = @"MVChatRoomUserPartedNotification";
NSString *MVChatRoomUserKickedNotification = @"MVChatRoomUserKickedNotification";
NSString *MVChatRoomUserBannedNotification = @"MVChatRoomUserBannedNotification";
NSString *MVChatRoomUserBanRemovedNotification = @"MVChatRoomUserBanRemovedNotification";
NSString *MVChatRoomUserModeChangedNotification = @"MVChatRoomUserModeChangedNotification";

NSString *MVChatRoomGotMessageNotification = @"MVChatRoomGotMessageNotification";
NSString *MVChatRoomTopicChangedNotification = @"MVChatRoomTopicChangedNotification";
NSString *MVChatRoomModeChangedNotification = @"MVChatRoomModeChangedNotification";
NSString *MVChatRoomAttributesUpdatedNotification = @"MVChatRoomAttributesUpdatedNotification";

@implementation MVChatRoom
- (id) init {
	if( ( self = [super init] ) ) {
		_connection = nil;
		_name = nil;
		_dateJoined = nil;
		_dateParted = nil;
		_topicData = nil;
		_topicAuthor = nil;
		_dateTopicChanged = nil;
		_attributes = [[NSMutableDictionary dictionaryWithCapacity:2] retain];
		_memberUsers = [[NSMutableSet setWithCapacity:30] retain];
		_bannedUsers = [[NSMutableSet setWithCapacity:2] retain];
		_modeAttributes = [[NSMutableDictionary dictionaryWithCapacity:2] retain];
		_memberModes = [[NSMutableDictionary dictionaryWithCapacity:30] retain];
		_encoding = NSUTF8StringEncoding;
		_modes = 0;
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_name release];
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
	NSParameterAssert( anotherRoom != nil );
	if( anotherRoom == self ) return YES;
	if( ! [[self connection] isEqual:[anotherRoom connection]] )
		return NO;
	if( ! [[self uniqueIdentifier] isEqual:[anotherRoom uniqueIdentifier]] )
		return NO;
	return YES;
}

- (unsigned) hash {
	return ( [[self uniqueIdentifier] hash] ^ [[self connection] hash] );
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
	return _name;
}

- (NSString *) displayName {
	return [self name];
}

- (id) uniqueIdentifier {
	return [[self name] lowercaseString];
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

- (void) sendMessage:(NSAttributedString *) message asAction:(BOOL) action {
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
	return _topicData;
}

- (MVChatUser *) topicAuthor {
	return _topicAuthor;
}

- (NSDate *) dateTopicChanged {
	return _dateTopicChanged;
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
	return _attributes;
}

- (BOOL) hasAttributeForKey:(NSString *) key {
	NSParameterAssert( [[self supportedAttributes] containsObject:key] );
	return ( [[self attributes] objectForKey:key] ? YES : NO );
}

- (id) attributeForKey:(NSString *) key {
	NSParameterAssert( [[self supportedAttributes] containsObject:key] );
	return [[self attributes] objectForKey:key];
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
	return [_modeAttributes objectForKey:[NSNumber numberWithUnsignedInt:mode]];
}

#pragma mark -

- (void) setModes:(unsigned long) modes {
	NSParameterAssert( [self supportedModes] & modes );
// subclass this method, call super first	
}

- (void) setMode:(MVChatRoomMode) mode {
	NSParameterAssert( [self supportedModes] & mode );
// subclass this method, call super first	
}

- (void) setMode:(MVChatRoomMode) mode withAttribute:(id) attribute {
	NSParameterAssert( [self supportedModes] & mode );
// subclass this method, call super first	
}

#pragma mark -

- (NSSet *) memberUsers {
	return _memberUsers;
}

- (NSSet *) memberUsersWithModes:(unsigned long) modes {
	NSMutableSet *users = [NSMutableSet set];
	NSEnumerator *enumerator = [[self memberUsers] objectEnumerator];
	MVChatUser *user = nil;

	while( ( user = [enumerator nextObject] ) )
		if( [self modesForMemberUser:user] & modes )
			[users addObject:user];

	return users;
}

- (NSSet *) memberUsersWithNickname:(NSString *) nickname {
	NSMutableSet *users = [NSMutableSet set];
	NSEnumerator *enumerator = [[self memberUsers] objectEnumerator];
	MVChatUser *user = nil;

	while( ( user = [enumerator nextObject] ) )
		if( [[user nickname] isEqualToString:nickname] )
			[users addObject:user];

	return users;
}

- (NSSet *) memberUsersWithFingerprint:(NSString *) fingerprint {
	NSMutableSet *users = [NSMutableSet set];
	NSEnumerator *enumerator = [[self memberUsers] objectEnumerator];
	MVChatUser *user = nil;

	while( ( user = [enumerator nextObject] ) )
		if( [[user fingerprint] isEqualToString:fingerprint] )
			[users addObject:user];

	return users;
}

- (MVChatUser *) memberUserWithUniqueIdentifier:(id) identifier {
	NSEnumerator *enumerator = [[self memberUsers] objectEnumerator];
	MVChatUser *user = nil;

	while( ( user = [enumerator nextObject] ) )
		if( [[user uniqueIdentifier] isEqual:identifier] )
			return user;

	return nil;
}

- (BOOL) hasUser:(MVChatUser *) user {
	NSParameterAssert( user != nil );
	return [[self memberUsers] containsObject:user];
}

#pragma mark -

- (NSSet *) bannedUsers {
	return _bannedUsers;
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
	return [[_memberModes objectForKey:[user uniqueIdentifier]] unsignedLongValue];
}

#pragma mark -

- (void) setModes:(unsigned long) modes forMemberUser:(MVChatUser *) user {
	NSParameterAssert( user != nil );
	NSParameterAssert( [self supportedMemberUserModes] & modes );
// subclass this method, call super first	
}

- (void) setMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user {
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
	[_memberUsers addObject:user];
}

- (void) _removeMemberUser:(MVChatUser *) user {
	[_memberModes removeObjectForKey:[user uniqueIdentifier]];
	[_memberUsers removeObject:user];
}

- (void) _addBanForUser:(MVChatUser *) user {
	[_bannedUsers addObject:user];
}

- (void) _removeBanForUser:(MVChatUser *) user {
	[_bannedUsers removeObject:user];
}

- (void) _setMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user {
	unsigned long modes = ( [self modesForMemberUser:user] | mode );
	[_memberModes setObject:[NSNumber numberWithUnsignedLong:modes] forKey:[user uniqueIdentifier]];
}

- (void) _clearModes {
	_modes = 0;
	[_modeAttributes removeAllObjects];
}

- (void) _setMode:(MVChatRoomMode) mode withAttribute:(id) attribute {
	_modes |= mode;

	if( attribute ) [_modeAttributes setObject:attribute forKey:[NSNumber numberWithUnsignedLong:mode]];
	else [_modeAttributes removeObjectForKey:[NSNumber numberWithUnsignedLong:mode]];
}

- (void) _setDateJoined:(NSDate *) date {
	[_dateJoined autorelease];
	_dateJoined = [date copy];
}

- (void) _setDateParted:(NSDate *) date {
	[_dateParted autorelease];
	_dateParted = [date copy];
}

- (void) _setTopic:(NSData *) topic byAuthor:(MVChatUser *) author withDate:(NSDate *) date {
	[_topicData autorelease];
	_topicData = [topic copy];

	[_topicAuthor autorelease];
	_topicAuthor = [author retain];

	[_dateTopicChanged autorelease];
	_dateTopicChanged = [date copy];
}
@end