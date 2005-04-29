typedef enum {
	MVChatRemoteUserType = 'remT',
	MVChatLocalUserType = 'locL',
	MVChatWildcardUserType = 'wilD'
} MVChatUserType;

typedef enum {
	MVChatUserUnknownStatus = 'uKnw',
	MVChatUserOfflineStatus = 'oflN',
	MVChatUserDetachedStatus = 'detA',
	MVChatUserAvailableStatus = 'avaL',
	MVChatUserAwayStatus = 'awaY'
} MVChatUserStatus;

typedef enum {
	MVChatUserNoModes = 0,
	MVChatUserInvisibleMode = 1 << 0
} MVChatUserMode;

extern NSString *MVChatUserKnownRoomsAttribute;
extern NSString *MVChatUserPictureAttribute;
extern NSString *MVChatUserLocalTimeDifferenceAttribute;
extern NSString *MVChatUserClientInfoAttribute;
extern NSString *MVChatUserVCardAttribute;
extern NSString *MVChatUserServiceAttribute;
extern NSString *MVChatUserMoodAttribute;
extern NSString *MVChatUserStatusMessageAttribute;
extern NSString *MVChatUserPreferredLanguageAttribute;
extern NSString *MVChatUserPreferredContactMethodsAttribute;
extern NSString *MVChatUserTimezoneAttribute;
extern NSString *MVChatUserGeoLocationAttribute;
extern NSString *MVChatUserDeviceInfoAttribute;
extern NSString *MVChatUserExtensionAttribute;
extern NSString *MVChatUserPublicKeyAttribute;
extern NSString *MVChatUserServerPublicKeyAttribute;
extern NSString *MVChatUserDigitalSignatureAttribute;
extern NSString *MVChatUserServerDigitalSignatureAttribute;

extern NSString *MVChatUserNicknameChangedNotification;
extern NSString *MVChatUserStatusChangedNotification;
extern NSString *MVChatUserAwayStatusMessageChangedNotification;
extern NSString *MVChatUserIdleTimeUpdatedNotification;
extern NSString *MVChatUserModeChangedNotification;
extern NSString *MVChatUserInformationUpdatedNotification;
extern NSString *MVChatUserAttributeUpdatedNotification;

@class MVChatConnection;
@class MVUploadFileTransfer;

@interface MVChatUser : NSObject {
@protected
	MVChatConnection *_connection;
	id _uniqueIdentifier;
	NSString *_nickname;
	NSString *_realName;
	NSString *_username;
	NSString *_address;
	NSString *_serverAddress;
	NSData *_publicKey;
	NSString *_fingerprint;
	NSDate *_dateConnected;
	NSDate *_dateDisconnected;
	NSDate *_dateUpdated;
	NSMutableDictionary *_attributes;
	MVChatUserType _type;
	MVChatUserStatus _status;
	NSTimeInterval _idleTime;
	NSTimeInterval _lag;
	unsigned long _modes;
	BOOL _identified;
	BOOL _serverOperator;
}
+ (id) wildcardUserWithNicknameMask:(NSString *) nickname andHostMask:(NSString *) host;
+ (id) wildcardUserWithFingerprint:(NSString *) fingerprint;

- (MVChatConnection *) connection;

- (MVChatUserType) type;

- (BOOL) isRemoteUser;
- (BOOL) isLocalUser;
- (BOOL) isWildcardUser;

- (BOOL) isIdentified;
- (BOOL) isServerOperator;

- (BOOL) isEqual:(id) object;
- (BOOL) isEqualToChatUser:(MVChatUser *) anotherUser;
- (unsigned) hash;

- (NSComparisonResult) compare:(MVChatUser *) otherUser;
- (NSComparisonResult) compareByNickname:(MVChatUser *) otherUser;
- (NSComparisonResult) compareByRealName:(MVChatUser *) otherUser;
- (NSComparisonResult) compareByIdleTime:(MVChatUser *) otherUser;

- (MVChatUserStatus) status;
- (NSAttributedString *) awayStatusMessage;

- (NSDate *) dateConnected;
- (NSDate *) dateDisconnected;
- (NSDate *) dateUpdated;

- (NSTimeInterval) idleTime;
- (NSTimeInterval) lag;

- (NSString *) displayName;
- (NSString *) nickname;
- (NSString *) realName;
- (NSString *) username;
- (NSString *) address;
- (NSString *) serverAddress;

- (id) uniqueIdentifier;
- (NSData *) publicKey;
- (NSString *) fingerprint;

- (unsigned long) supportedModes;
- (unsigned long) modes;

- (void) startWatching;
- (void) stopWatching;

- (void) refreshInformation;

- (void) refreshAttributes;
- (void) refreshAttributeForKey:(NSString *) key;

- (NSSet *) supportedAttributes;

- (NSDictionary *) attributes;
- (BOOL) hasAttributeForKey:(NSString *) key;
- (id) attributeForKey:(NSString *) key;

- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action;
- (MVUploadFileTransfer *) sendFile:(NSString *) path passively:(BOOL) passive;

- (void) sendSubcodeRequest:(NSString *) command withArguments:(NSString *) arguments;
- (void) sendSubcodeReply:(NSString *) command withArguments:(NSString *) arguments;
@end

#pragma mark -

@interface MVChatUser (MVChatUserScripting)
- (NSString *) scriptUniqueIdentifier;
- (NSScriptObjectSpecifier *) objectSpecifier;
@end