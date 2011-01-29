#import "MVChatUser.h"
#import "MVChatConnection.h"
#import "MVChatConnectionPrivate.h"
#import "MVFileTransfer.h"
#import "NSNotificationAdditions.h"
#import "NSDataAdditions.h"
#import "MVUtilities.h"

NSString *MVChatUserKnownRoomsAttribute = @"MVChatUserKnownRoomsAttribute";
NSString *MVChatUserPictureAttribute = @"MVChatUserPictureAttribute";
NSString *MVChatUserPingAttribute = @"MVChatUserPingAttribute";
NSString *MVChatUserLocalTimeAttribute = @"MVChatUserLocalTimeAttribute";
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
NSString *MVChatUserBanServerAttribute = @"MVChatUserBanServerAttribute";
NSString *MVChatUserBanAuthorAttribute = @"MVChatUserBanAuthorAttribute";
NSString *MVChatUserBanDateAttribute = @"MVChatUserBanDateAttribute";

NSString *MVChatUserNicknameChangedNotification = @"MVChatUserNicknameChangedNotification";
NSString *MVChatUserStatusChangedNotification = @"MVChatUserStatusChangedNotification";
NSString *MVChatUserAwayStatusMessageChangedNotification = @"MVChatUserAwayStatusMessageChangedNotification";
NSString *MVChatUserIdleTimeUpdatedNotification = @"MVChatUserIdleTimeUpdatedNotification";
NSString *MVChatUserModeChangedNotification = @"MVChatUserModeChangedNotification";
NSString *MVChatUserInformationUpdatedNotification = @"MVChatUserInformationUpdatedNotification";
NSString *MVChatUserAttributeUpdatedNotification = @"MVChatUserAttributeUpdatedNotification";

@implementation MVChatUser
#if ENABLE(SCRIPTING)
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
#endif

#pragma mark -

+ (id) wildcardUserFromString:(NSString *) mask {
	NSArray *parts = [mask componentsSeparatedByString:@"!"];
	if( parts.count == 1 )
		return [self wildcardUserWithNicknameMask:[parts objectAtIndex:0] andHostMask:nil];
	if( parts.count >= 2 )
		return [self wildcardUserWithNicknameMask:[parts objectAtIndex:0] andHostMask:[parts objectAtIndex:1]];
	return [self wildcardUserWithNicknameMask:mask andHostMask:nil];
}

+ (id) wildcardUserWithNicknameMask:(NSString *) nickname andHostMask:(NSString *) host {
	MVChatUser *ret = [[self allocWithZone:nil] init];
	ret -> _type = MVChatWildcardUserType;

	NSArray *parts = [nickname componentsSeparatedByString:@"@"];
	if( parts.count >= 1 )
		ret -> _nickname = [[parts objectAtIndex:0] copyWithZone:[ret zone]];
	if( parts.count >= 2 )
		ret -> _serverAddress = [[parts objectAtIndex:1] copyWithZone:[ret zone]];

	parts = [host componentsSeparatedByString:@"@"];
	if( parts.count >= 1 )
		ret -> _username = [[parts objectAtIndex:0] copyWithZone:[ret zone]];
	if( parts.count >= 2 )
		ret -> _address = [[parts objectAtIndex:1] copyWithZone:[ret zone]];

	return [ret autorelease];
}

+ (id) wildcardUserWithFingerprint:(NSString *) fingerprint {
	MVChatUser *ret = [[self allocWithZone:nil] init];
	ret -> _type = MVChatWildcardUserType;
	ret -> _fingerprint = [fingerprint copyWithZone:[ret zone]];
	return [ret autorelease];
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		_attributes = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:5];
		_type = MVChatRemoteUserType;
		_status = MVChatUserUnknownStatus;
	}

	return self;
}

- (void) dealloc {
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

	[super dealloc];
}

#pragma mark -

- (MVChatConnection *) connection {
	return _connection;
}

- (MVChatUserType) type {
	return _type;
}

#pragma mark -

- (BOOL) isRemoteUser {
	return ( _type == MVChatRemoteUserType );
}

- (BOOL) isLocalUser {
	return ( _type == MVChatLocalUserType );
}

- (BOOL) isWildcardUser {
	return ( _type == MVChatWildcardUserType );
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
	if( _type == MVChatWildcardUserType || [(MVChatUser *)object type] == MVChatWildcardUserType )
		return [self isEqualToChatUser:object];
	if( ! [object isKindOfClass:[self class]] ) return NO;
	return [self isEqualToChatUser:object];
}

- (BOOL) isEqualToChatUser:(MVChatUser *) anotherUser {
	if( ! anotherUser ) return NO;
	if( anotherUser == self ) return YES;

	if( _type == MVChatWildcardUserType || anotherUser -> _type == MVChatWildcardUserType ) {
		NSString *string1 = [self fingerprint];
		NSString *string2 = [anotherUser fingerprint];
		if( string2 && string1 && ! [string1 isEqualToString:string2] )
			return NO;
		string1 = [self nickname];
		string2 = [anotherUser nickname];
		if( string2 && string1 && ! [string1 isEqualToString:string2] )
			return NO;
		string1 = [self username];
		string2 = [anotherUser username];
		if( string2 && string1 && ! [string1 isEqualToString:string2] )
			return NO;
		string1 = [self address];
		string2 = [anotherUser address];
		if( string2 && string1 && ! [string1 isEqualToString:string2] )
			return NO;
		string1 = [self serverAddress];
		string2 = [anotherUser serverAddress];
		if( string2 && string1 && ! [string1 isEqualToString:string2] )
			return NO;
		return YES;
	}

	if( _type != anotherUser -> _type ) return NO;

	if( ! [[self connection] isEqual:[anotherUser connection]] )
		return NO;

	if( ! [[self uniqueIdentifier] isEqual:[anotherUser uniqueIdentifier]] )
		return NO;

	return YES;
}

- (NSUInteger) hash {
	if( _type == MVChatWildcardUserType && ! _hash )
		_hash = ( _type ^ [[self nickname] hash] ^ [[self username] hash] ^ [[self address] hash] ^ [[self serverAddress] hash] ^ [[self fingerprint] hash] );
	if( ! _hash ) _hash = ( _type ^ [[self connection] hash] ^ [[self uniqueIdentifier] hash] );
	return _hash;
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

- (NSData *) awayStatusMessage {
	return _awayStatusMessage;
}

#pragma mark -

- (NSDate *) dateConnected {
	return _dateConnected;
}

- (NSDate *) dateDisconnected {
	return _dateDisconnected;
}

- (NSDate *) dateUpdated {
	return _dateUpdated;
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
	if( _type == MVChatWildcardUserType )
		return [NSString stringWithFormat:@"%@!%@@%@", ( [self nickname] ? [self nickname] : @"*" ), ( [self username] ? [self username] : @"*" ), ( [self address] ? [self address] : @"*" )];
	return [self nickname];
}

- (NSString *) nickname {
	if( _type == MVChatLocalUserType )
		return [[self connection] nickname];
	return _nickname;
}

- (NSString *) realName {
	if( _type == MVChatLocalUserType )
		return [[self connection] realName];
	return _realName;
}

- (NSString *) username {
	if( _type == MVChatLocalUserType )
		return [[self connection] username];
	return _username;
}

- (NSString *) address {
	return _address;
}

- (NSString *) serverAddress {
	if( ! _serverAddress ) return [[self connection] server];
	return _serverAddress;
}

#pragma mark -

- (id) uniqueIdentifier {
	return _uniqueIdentifier;
}

- (NSData *) publicKey {
	return _publicKey;
}

- (NSString *) fingerprint {
	return _fingerprint;
}

#pragma mark -

- (NSUInteger) supportedModes {
// subclass this method, if needed
	return 0;
}

- (NSUInteger) modes {
	return _modes;
}

#pragma mark -

- (void) refreshInformation {
// subclass this method, if needed
}

#pragma mark -

- (void) refreshAttributes {
	for( NSString *attribute in [self supportedAttributes] )
		[self refreshAttributeForKey:attribute];
}

- (void) refreshAttributeForKey:(NSString *) key {
	NSParameterAssert( [[self supportedAttributes] containsObject:key] );
// subclass this method, call super first
}

#pragma mark -

- (NSSet *) supportedAttributes {
	return [NSSet setWithObjects:MVChatUserBanServerAttribute, MVChatUserBanAuthorAttribute, MVChatUserBanDateAttribute, nil];
}

#pragma mark -

- (NSDictionary *) attributes {
	@synchronized( _attributes ) {
		return [NSDictionary dictionaryWithDictionary:_attributes];
	}
}

- (BOOL) hasAttributeForKey:(NSString *) key {
	@synchronized( _attributes ) {
		return ( [_attributes objectForKey:key] ? YES : NO );
	}
}

- (id) attributeForKey:(NSString *) key {
	@synchronized( _attributes ) {
		return [_attributes objectForKey:key];
	}
}

- (void) setAttribute:(id) attribute forKey:(id) key {
	NSParameterAssert( key != nil );
	@synchronized( _attributes ) {
		if( attribute ) [_attributes setObject:attribute forKey:key];
		else [_attributes removeObjectForKey:key];
	}

	NSDictionary *info = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:key, @"attribute", nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatUserAttributeUpdatedNotification object:self userInfo:info];
	[info release];
}

#pragma mark -

- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action {
	[self sendMessage:message withEncoding:encoding withAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:action] forKey:@"action"]];
}

- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding withAttributes:(NSDictionary *) attributes {
	// subclass this method, don't call super
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (void) sendCommand:(NSString *) command withArguments:(MVChatString *) arguments withEncoding:(NSStringEncoding) encoding {
	// subclass this method, don't call super
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (MVUploadFileTransfer *) sendFile:(NSString *) path passively:(BOOL) passive {
	return [MVUploadFileTransfer transferWithSourceFile:path toUser:self passively:passive];
}

#pragma mark -

- (void) sendSubcodeRequest:(NSString *) command withArguments:(id) arguments {
// subclass this method, if needed
}

- (void) sendSubcodeReply:(NSString *) command withArguments:(id) arguments {
// subclass this method, if needed
}

#pragma mark -

- (NSString *) description {
	return [self displayName];
}
@end

#pragma mark -

@implementation MVChatUser (MVChatUserPrivate)
- (void) _connectionDestroyed {
	_connection = nil;
}

- (void) _setType:(MVChatUserType) type {
	_type = type;
}

- (void) _setUniqueIdentifier:(id) identifier {
	MVSafeAdoptAssign( _uniqueIdentifier, ( [identifier conformsToProtocol:@protocol( NSCopying )] ? [identifier copyWithZone:nil] : [identifier retain] ) );
}

- (void) _setNickname:(NSString *) name {
	MVSafeCopyAssign( _nickname, name );
}

- (void) _setRealName:(NSString *) name {
	MVSafeCopyAssign( _realName, name );
}

- (void) _setUsername:(NSString *) name {
	MVSafeCopyAssign( _username, name );
}

- (void) _setAddress:(NSString *) newAddress {
	MVSafeCopyAssign( _address, newAddress );
}

- (void) _setServerAddress:(NSString *) newServerAddress {
	MVSafeCopyAssign( _serverAddress, newServerAddress );
}

- (void) _setPublicKey:(NSData *) key {
	MVSafeCopyAssign( _publicKey, key );
}

- (void) _setFingerprint:(NSString *) newFingerprint {
	MVSafeCopyAssign( _fingerprint, newFingerprint );
}

- (void) _setServerOperator:(BOOL) isServerOperator {
	_serverOperator = isServerOperator;
}

- (void) _setIdentified:(BOOL) isIdentified {
	_identified = isIdentified;
}

- (void) _setIdleTime:(NSTimeInterval) time {
	_idleTime = time;
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatUserIdleTimeUpdatedNotification object:self userInfo:nil];
}

- (void) _setStatus:(MVChatUserStatus) newStatus {
	if( _status == newStatus ) return;
	_status = newStatus;
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatUserStatusChangedNotification object:self userInfo:nil];
}

- (void) _setDateConnected:(NSDate *) date {
	MVSafeCopyAssign( _dateConnected, date );
}

- (void) _setDateDisconnected:(NSDate *) date {
	MVSafeCopyAssign( _dateDisconnected, date );
}

- (void) _setDateUpdated:(NSDate *) date {
	MVSafeCopyAssign( _dateUpdated, date );
}

- (void) _setAwayStatusMessage:(NSData *) newAwayStatusMessage {
	MVSafeCopyAssign( _awayStatusMessage, newAwayStatusMessage );
}

- (BOOL) _onlineNotificationSent {
	return _onlineNotificationSent;
}

- (void) _setOnlineNotificationSent:(BOOL) sent {
	_onlineNotificationSent = sent;
}
@end

#pragma mark -

#if ENABLE(SCRIPTING)
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
		return [[[NSPropertySpecifier allocWithZone:nil] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"localUser"] autorelease];
	}

	id classDescription = [NSClassDescription classDescriptionForClass:[MVChatConnection class]];
	NSScriptObjectSpecifier *container = [[self connection] objectSpecifier];
	return [[[NSUniqueIDSpecifier allocWithZone:nil] initWithContainerClassDescription:classDescription containerSpecifier:container key:@"knownChatUsersArray" uniqueID:[self scriptUniqueIdentifier]] autorelease];
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
#endif
