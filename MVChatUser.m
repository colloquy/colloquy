#import "MVChatUser.h"
#import "MVChatConnection.h"
#import "MVFileTransfer.h"

NSString *MVChatUserKnownRoomsAttribute = @"MVChatUserKnownRoomsAttribute";
NSString *MVChatUserPictureAttribute = @"MVChatUserPictureAttribute";
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

NSString *MVChatUserNicknameChangedNotification = @"MVChatUserNicknameChangedNotification";
NSString *MVChatUserStatusChangedNotification = @"MVChatUserStatusChangedNotification";
NSString *MVChatUserAwayStatusMessageChangedNotification = @"MVChatUserAwayStatusMessageChangedNotification";
NSString *MVChatUserIdleTimeUpdatedNotification = @"MVChatUserIdleTimeUpdatedNotification";
NSString *MVChatUserModeChangedNotification = @"MVChatUserModeChangedNotification";
NSString *MVChatUserInformationUpdatedNotification = @"MVChatUserInformationUpdatedNotification";
NSString *MVChatUserAttributeUpdatedNotification = @"MVChatUserAttributeUpdatedNotification";
NSString *MVChatUserAttributesUpdatedNotification = @"MVChatUserAttributesUpdatedNotification";

@implementation MVChatUser
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
		_status = MVChatUserOfflineStatus;
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
	if( ! object || ! [object isKindOfClass:[self class]] ) return NO;
	return [self isEqualToChatUser:object];
}

- (BOOL) isEqualToChatUser:(MVChatUser *) anotherUser {
	NSParameterAssert( anotherUser != nil );
	if( anotherUser == self ) return YES;
	if( ! [[self connection] isEqual:[anotherUser connection]] )
		return NO;
	if( ! [[self uniqueIdentifier] isEqual:[anotherUser uniqueIdentifier]] )
		return NO;
	return YES;
}

- (unsigned) hash {
	return ( [self type] ^ [[self connection] hash] );
}

#pragma mark -

- (NSComparisonResult) compare:(MVChatUser *) otherUser {
	return [[self nickname] compare:[otherUser nickname]];
}

- (NSComparisonResult) compareByNickname:(MVChatUser *) otherUser {
	return [[self nickname] compare:[otherUser nickname]];
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

#pragma mark -

- (NSTimeInterval) idleTime {
	return _idleTime;
}

- (NSTimeInterval) lag {
	return _lag;
}

#pragma mark -

- (NSString *) displayName {
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
	NSDictionary *ret = nil;
	@synchronized( _attributes ) {
		ret = [NSDictionary dictionaryWithDictionary:_attributes];
	} return ret;
}

- (BOOL) hasAttributeForKey:(NSString *) key {
	NSParameterAssert( [[self supportedAttributes] containsObject:key] );
	BOOL ret = NO;
	@synchronized( _attributes ) {
		ret = ( [_attributes objectForKey:key] ? YES : NO );
	} return ret;
}

- (id) attributeForKey:(NSString *) key {
	NSParameterAssert( [[self supportedAttributes] containsObject:key] );
	id ret = nil;
	@synchronized( _attributes ) {
		ret = [_attributes objectForKey:key];
	} return [[ret retain] autorelease];
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
	return [self nickname];
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
}

- (void) _setDateConnected:(NSDate *) date {
	[_dateConnected autorelease];
	_dateConnected = [date copyWithZone:[self zone]];
}

- (void) _setDateDisconnected:(NSDate *) date {
	[_dateDisconnected autorelease];
	_dateDisconnected = [date copyWithZone:[self zone]];
}
@end