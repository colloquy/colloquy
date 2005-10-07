#import "MVChatUser.h"
#import "MVChatConnection.h"
#import "MVFileTransfer.h"
#import "NSNotificationAdditions.h"
#import "NSDataAdditions.h"

NSString *MVChatUserKnownRoomsAttribute = @"MVChatUserKnownRoomsAttribute";
NSString *MVChatUserPictureAttribute = @"MVChatUserPictureAttribute";
NSString *MVChatUserLocalTimeDifferenceAttribute = @"MVChatUserLocalTimeDifferenceAttribute";
NSString *MVChatUserClientInfoAttribute = @"MVChatUserClientInfoAttribute";
NSString *MVChatUserVCardAttribute = @"MVChatUserVCardAttribute";
NSString *MVChatUserServiceAttribute = @"MVChatUserServiceAttribute";
NSString *MVChatUserMoodAttribute = @"MVChatUserMoodAttribute";
NSString *MVChatUserStatusMessageAttribute = @"MVChatUserStatusMessageAttribute";
NSString *MVChatUserPreferredLanguageAttribute = @"MVChatUserPreferredLanguageAttribute";
NSString *MVChatUserPreferredContactMethodsAttribute = @"MVChatUserPreferredContactMethodsAttribute";
NSString *MVChatUserTimezoneAttribute = @"MVChatUserTimezoneAttribute";
NSString *MVChatUserGeoLocationAttribute = @"MVChatUserGeoLocationAttribute";
NSString *MVChatUserDeviceInfoAttribute = @"MVChatUserDeviceInfoAttribute";
NSString *MVChatUserExtensionAttribute = @"MVChatUserExtensionAttribute";
NSString *MVChatUserPublicKeyAttribute = @"MVChatUserPublicKeyAttribute";
NSString *MVChatUserServerPublicKeyAttribute = @"MVChatUserServerPublicKeyAttribute";
NSString *MVChatUserDigitalSignatureAttribute = @"MVChatUserDigitalSignatureAttribute";
NSString *MVChatUserServerDigitalSignatureAttribute = @"MVChatUserServerDigitalSignatureAttribute";

NSString *MVChatUserNicknameChangedNotification = @"MVChatUserNicknameChangedNotification";
NSString *MVChatUserStatusChangedNotification = @"MVChatUserStatusChangedNotification";
NSString *MVChatUserAwayStatusMessageChangedNotification = @"MVChatUserAwayStatusMessageChangedNotification";
NSString *MVChatUserIdleTimeUpdatedNotification = @"MVChatUserIdleTimeUpdatedNotification";
NSString *MVChatUserModeChangedNotification = @"MVChatUserModeChangedNotification";
NSString *MVChatUserInformationUpdatedNotification = @"MVChatUserInformationUpdatedNotification";
NSString *MVChatUserAttributeUpdatedNotification = @"MVChatUserAttributeUpdatedNotification";

@implementation MVChatUser
+ (void) initialize {
	[super initialize];
	static BOOL tooLate = NO;
	if( ! tooLate ) {
		[[NSScriptCoercionHandler sharedCoercionHandler] registerCoercer:[self class] selector:@selector( coerceChatUser:toString: ) toConvertFromClass:[MVChatUser class] toClass:[NSString class]];
		tooLate = YES;
	}
}

+ (id) coerceChatUser:(id) value toString:(Class) class {
	return [value nickname];
}

#pragma mark -

+ (id) wildcardUserFromString:(NSString *) mask {
	NSArray *parts = [mask componentsSeparatedByString:@"!"];
	if( [parts count] == 1 ) {
		return [self wildcardUserWithNicknameMask:[parts objectAtIndex:0] andHostMask:nil];
	} else if( [parts count] >= 2 ) {
		return [self wildcardUserWithNicknameMask:[parts objectAtIndex:0] andHostMask:[parts objectAtIndex:1]];
	}

	return [self wildcardUserWithNicknameMask:mask andHostMask:nil];
}

+ (id) wildcardUserWithNicknameMask:(NSString *) nickname andHostMask:(NSString *) host {
	MVChatUser *ret = [[[self alloc] init] autorelease];
	ret -> _type = MVChatWildcardUserType;

	NSArray *parts = [nickname componentsSeparatedByString:@"@"];
	if( [parts count] >= 1 )
		ret -> _nickname = [[parts objectAtIndex:0] copyWithZone:[ret zone]];
	if( [parts count] >= 2 )
		ret -> _serverAddress = [[parts objectAtIndex:1] copyWithZone:[ret zone]];

	parts = [host componentsSeparatedByString:@"@"];
	if( [parts count] >= 1 )
		ret -> _username = [[parts objectAtIndex:0] copyWithZone:[ret zone]];
	if( [parts count] >= 2 )
		ret -> _address = [[parts objectAtIndex:1] copyWithZone:[ret zone]];

	return ret;
}

+ (id) wildcardUserWithFingerprint:(NSString *) fingerprint {
	MVChatUser *ret = [[[self alloc] init] autorelease];
	ret -> _type = MVChatWildcardUserType;
	ret -> _fingerprint = [fingerprint copyWithZone:[ret zone]];
	return ret;
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_connection = nil;
		_uniqueIdentifier = nil;
		_nickname = nil;
		_realName = nil;
		_username = nil;
		_address = nil;
		_serverAddress = nil;
		_publicKey = nil;
		_fingerprint = nil;
		_dateConnected = nil;
		_dateDisconnected = nil;
		_attributes = [[NSMutableDictionary dictionaryWithCapacity:5] retain];
		_type = MVChatRemoteUserType;
		_status = MVChatUserUnknownStatus;
		_modes = 0;
		_idleTime = 0.;
		_lag = 0.;
		_identified = NO;
		_serverOperator = NO;
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_uniqueIdentifier release];
	[_nickname release];
	[_realName release];
	[_username release];
	[_address release];
	[_serverAddress release];
	[_publicKey release];
	[_fingerprint release];
	[_dateConnected release];
	[_dateDisconnected release];
	[_attributes release];

	_connection = nil; // connection isn't retained, prevents circular retain
	_uniqueIdentifier = nil;
	_nickname = nil;
	_realName = nil;
	_username = nil;
	_address = nil;
	_serverAddress = nil;
	_publicKey = nil;
	_fingerprint = nil;
	_dateConnected = nil;
	_dateDisconnected = nil;
	_attributes = nil;

	[super dealloc];
}

#pragma mark -

- (MVChatConnection *) connection {
	return _connection;
}

#pragma mark -

- (MVChatUserType) type {
	return _type;
}

#pragma mark -

- (BOOL) isRemoteUser {
	return ( [self type] == MVChatRemoteUserType );
}

- (BOOL) isLocalUser {
	return ( [self type] == MVChatLocalUserType );
}

- (BOOL) isWildcardUser {
	return ( [self type] == MVChatWildcardUserType );
}

#pragma mark -

- (BOOL) isIdentified {
	return _identified;
}

- (BOOL) isServerOperator {
	return _serverOperator;
}

#pragma mark -

- (BOOL) isEqual:(id) object {
	if( object == self ) return YES;
	if( ! object || ! [object isKindOfClass:[MVChatUser class]] ) return NO;
	if( [self type] == MVChatWildcardUserType || [(MVChatUser *)object type] == MVChatWildcardUserType )
		return [self isEqualToChatUser:object];
	if( ! [object isKindOfClass:[self class]] ) return NO;
	return [self isEqualToChatUser:object];
}

- (BOOL) isEqualToChatUser:(MVChatUser *) anotherUser {
	if( anotherUser == self ) return YES;
	if( ! anotherUser || ! [anotherUser isKindOfClass:[MVChatUser class]] ) return NO;

	if( [self type] == MVChatWildcardUserType || [anotherUser type] == MVChatWildcardUserType ) {
		if( ( [self fingerprint] && [anotherUser fingerprint] ) && ! [[self fingerprint] isEqualToString:[anotherUser fingerprint]] )
			return NO;
		if( ( [self nickname] && [anotherUser nickname] ) && ! [[self nickname] isEqualToString:[anotherUser nickname]] )
			return NO;
		if( ( [self username] && [anotherUser username] ) && ! [[self username] isEqualToString:[anotherUser username]] )
			return NO;
		if( ( [self address] && [anotherUser address] ) && ! [[self address] isEqualToString:[anotherUser address]] )
			return NO;
		if( ( [self serverAddress] && [anotherUser serverAddress] ) && ! [[self serverAddress] isEqualToString:[anotherUser serverAddress]] )
			return NO;
		return YES;
	}

	if( [self type] != [anotherUser type] ) return NO;

	if( ! [[self connection] isEqual:[anotherUser connection]] )
		return NO;

	if( ! [[self uniqueIdentifier] isEqual:[anotherUser uniqueIdentifier]] )
		return NO;

	return YES;
}

- (unsigned) hash {
	if( [self type] == MVChatWildcardUserType )
		return ( [self type] ^ [[self nickname] hash] ^ [[self username] hash] ^ [[self address] hash] ^ [[self serverAddress] hash] ^ [[self fingerprint] hash] );
	return ( [self type] ^ [[self connection] hash] );
}

#pragma mark -

- (NSComparisonResult) compare:(MVChatUser *) otherUser {
	return [[self nickname] compare:[otherUser nickname]];
}

- (NSComparisonResult) compareByNickname:(MVChatUser *) otherUser {
	return [[self nickname] compare:[otherUser nickname]];
}

- (NSComparisonResult) compareByUsername:(MVChatUser *) otherUser {
	return [[self username] compare:[otherUser username]];
}

- (NSComparisonResult) compareByAddress:(MVChatUser *) otherUser {
	return [[self address] compare:[otherUser address]];
}

- (NSComparisonResult) compareByRealName:(MVChatUser *) otherUser {
	return [[self realName] compare:[otherUser realName]];
}

- (NSComparisonResult) compareByIdleTime:(MVChatUser *) otherUser {
	NSTimeInterval idle1 = [self idleTime];
	NSTimeInterval idle2 = [otherUser idleTime];
	return ( idle1 == idle2 ? NSOrderedSame : ( idle1 > idle2 ? NSOrderedAscending : NSOrderedDescending ) );
}

#pragma mark -

- (MVChatUserStatus) status {
	return _status;
}

- (NSAttributedString *) awayStatusMessage {
// subclass this method, if needed
	return nil;
}

#pragma mark -

- (NSDate *) dateConnected {
	return [[_dateConnected retain] autorelease];
}

- (NSDate *) dateDisconnected {
	return [[_dateDisconnected retain] autorelease];
}

- (NSDate *) dateUpdated {
	return [[_dateUpdated retain] autorelease];
}

#pragma mark -

- (NSTimeInterval) idleTime {
	return _idleTime;
}

- (NSTimeInterval) lag {
	return _lag;
}

#pragma mark -

- (NSString *) displayName {
	if( [self type] == MVChatWildcardUserType )
		return [NSString stringWithFormat:@"%@!%@@%@", ( [self nickname] ? [self nickname] : @"*" ), ( [self username] ? [self username] : @"*" ), ( [self address] ? [self address] : @"*" )];
	return [self nickname];
}

- (NSString *) nickname {
	if( [self isLocalUser] )
		return [[self connection] nickname];
	return [[_nickname retain] autorelease];
}

- (NSString *) realName {
	if( [self isLocalUser] )
		return [[self connection] realName];
	return [[_realName retain] autorelease];
}

- (NSString *) username {
	if( [self isLocalUser] )
		return [[self connection] username];
	return [[_username retain] autorelease];
}

- (NSString *) address {
	return [[_address retain] autorelease];
}

- (NSString *) serverAddress {
	if( ! _serverAddress ) return [[self connection] server];
	return [[_serverAddress retain] autorelease];
}

#pragma mark -

- (id) uniqueIdentifier {
	return [[_uniqueIdentifier retain] autorelease];
}

- (NSData *) publicKey {
	return [[_publicKey retain] autorelease];
}

- (NSString *) fingerprint {
	return [[_fingerprint retain] autorelease];
}

#pragma mark -

- (unsigned long) supportedModes {
// subclass this method, if needed
	return 0;
}

- (unsigned long) modes {
	return _modes;
}

#pragma mark -

- (void) startWatching {
	[[self connection] startWatchingUser:self];
}

- (void) stopWatching {
	[[self connection] stopWatchingUser:self];
}

#pragma mark -

- (void) refreshInformation {
// subclass this method, if needed
}

#pragma mark -

- (void) refreshAttributes {
	NSEnumerator *enumerator = [[self supportedAttributes] objectEnumerator];
	NSString *attribute = nil;
	while( ( attribute = [enumerator nextObject] ) )
		[self refreshAttributeForKey:attribute];
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

	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:key, @"attribute", nil];
	NSNotification *note = [NSNotification notificationWithName:MVChatUserAttributeUpdatedNotification object:self userInfo:info];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

#pragma mark -

- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action {
// subclass this method, don't call super
	[self doesNotRecognizeSelector:_cmd];
}

- (MVUploadFileTransfer *) sendFile:(NSString *) path passively:(BOOL) passive {
	return [MVUploadFileTransfer transferWithSourceFile:path toUser:self passively:passive];
}

#pragma mark -

- (void) sendSubcodeRequest:(NSString *) command withArguments:(NSString *) arguments {
// subclass this method, if needed
}

- (void) sendSubcodeReply:(NSString *) command withArguments:(NSString *) arguments {
// subclass this method, if needed
}

#pragma mark -

- (NSString *) description {
	return [self displayName];
}
@end

#pragma mark -

@implementation MVChatUser (MVChatUserPrivate)
- (void) _setUniqueIdentifier:(id) identifier {
	[_uniqueIdentifier autorelease];
	_uniqueIdentifier = ( [identifier conformsToProtocol:@protocol( NSCopying )] ? [identifier copyWithZone:[self zone]] : [identifier retain] );
}

- (void) _setNickname:(NSString *) name {
	[_nickname autorelease];
	_nickname = [name copyWithZone:[self zone]];
}

- (void) _setRealName:(NSString *) name {
	[_realName autorelease];
	_realName = [name copyWithZone:[self zone]];
}

- (void) _setUsername:(NSString *) name {
	[_username autorelease];
	_username = [name copyWithZone:[self zone]];
}

- (void) _setAddress:(NSString *) address {
	[_address autorelease];
	_address = [address copyWithZone:[self zone]];
}

- (void) _setServerAddress:(NSString *) address {
	[_serverAddress autorelease];
	_serverAddress = [address copyWithZone:[self zone]];
}

- (void) _setPublicKey:(NSData *) key {
	[_publicKey autorelease];
	_publicKey = [key copyWithZone:[self zone]];
}

- (void) _setFingerprint:(NSString *) fingerprint {
	[_fingerprint autorelease];
	_fingerprint = [fingerprint copyWithZone:[self zone]];
}

- (void) _setServerOperator:(BOOL) operator {
	_serverOperator = operator;
}

- (void) _setIdentified:(BOOL) identified {
	_identified = identified;
}

- (void) _setIdleTime:(NSTimeInterval) time {
	_idleTime = time;

	NSNotification *note = [NSNotification notificationWithName:MVChatUserIdleTimeUpdatedNotification object:self userInfo:nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

- (void) _setStatus:(MVChatUserStatus) status {
	if( _status == status ) return;
	_status = status;

	NSNotification *note = [NSNotification notificationWithName:MVChatUserStatusChangedNotification object:self userInfo:nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

- (void) _setDateConnected:(NSDate *) date {
	[_dateConnected autorelease];
	_dateConnected = [date copyWithZone:[self zone]];
}

- (void) _setDateDisconnected:(NSDate *) date {
	[_dateDisconnected autorelease];
	_dateDisconnected = [date copyWithZone:[self zone]];
}

- (void) _setDateUpdated:(NSDate *) date {
	[_dateUpdated autorelease];
	_dateUpdated = [date copyWithZone:[self zone]];
}
@end

#pragma mark -

@implementation MVChatUser (MVChatUserScripting)
- (NSString *) scriptUniqueIdentifier {
	if( [[self uniqueIdentifier] isKindOfClass:[NSString class]] )
		return [self uniqueIdentifier];

	if( [[self uniqueIdentifier] isKindOfClass:[NSData class]] )
		return [[self uniqueIdentifier] base64Encoding];

	return [[self uniqueIdentifier] description];
}

- (NSScriptObjectSpecifier *) objectSpecifier {
	if( self == [[self connection] localUser] ) {
		id classDescription = [NSClassDescription classDescriptionForClass:[MVChatConnection class]];
		NSScriptObjectSpecifier *container = [[self connection] objectSpecifier];
		return [[[NSPropertySpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"localUser"] autorelease];
	}

	id classDescription = [NSClassDescription classDescriptionForClass:[MVChatConnection class]];
	NSScriptObjectSpecifier *container = [[self connection] objectSpecifier];
	return [[[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"knownChatUsersArray" uniqueID:[self scriptUniqueIdentifier]] autorelease];
}

- (void) refreshInformationScriptCommand:(NSScriptCommand *) command {
	[self refreshInformation];
}

#pragma mark -

- (id) valueForUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The chat user id \"%@\" of connection id %@ doesn't have the \"%@\" property.", [self scriptUniqueIdentifier], [[self connection] uniqueIdentifier], key]];
		return nil;
	}

	return [super valueForUndefinedKey:key];
}

- (void) setValue:(id) value forUndefinedKey:(NSString *) key {
	if( [NSScriptCommand currentCommand] ) {
		[[NSScriptCommand currentCommand] setScriptErrorNumber:1000];
		[[NSScriptCommand currentCommand] setScriptErrorString:[NSString stringWithFormat:@"The \"%@\" property of chat user id \"%@\" of connection id %@ is read only.", key, [self scriptUniqueIdentifier], [[self connection] uniqueIdentifier]]];
		return;
	}

	[super setValue:value forUndefinedKey:key];
}
@end