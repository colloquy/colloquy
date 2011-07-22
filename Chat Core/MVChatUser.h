#import "MVAvailability.h"
#import "MVChatString.h"

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
extern NSString *MVChatUserPingAttribute;
extern NSString *MVChatUserLocalTimeAttribute;
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
extern NSString *MVChatUserBanServerAttribute;
extern NSString *MVChatUserBanAuthorAttribute;
extern NSString *MVChatUserBanDateAttribute;

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
	NSData *_awayStatusMessage;
	NSMutableDictionary *_attributes;
	MVChatUserType _type;
	MVChatUserStatus _status;
	NSTimeInterval _idleTime;
	NSTimeInterval _lag;
	NSUInteger _modes;
	NSUInteger _hash;
	BOOL _identified;
	BOOL _serverOperator;
	BOOL _onlineNotificationSent;
}
+ (id) wildcardUserFromString:(NSString *) mask;
+ (id) wildcardUserWithNicknameMask:(NSString *) nickname andHostMask:(NSString *) host;
+ (id) wildcardUserWithFingerprint:(NSString *) fingerprint;

@property(readonly) MVChatConnection *connection;
@property(readonly) MVChatUserType type;

@property(readonly, getter=isRemoteUser) BOOL remoteUser;
@property(readonly, getter=isLocalUser) BOOL localUser;
@property(readonly, getter=isWildcardUser) BOOL wildcardUser;

@property(readonly, getter=isIdentified) BOOL identified;
@property(readonly, getter=isServerOperator) BOOL serverOperator;

@property(readonly) MVChatUserStatus status;
@property(readonly) NSData *awayStatusMessage;

@property(readonly) NSDate *dateConnected;
@property(readonly) NSDate *dateDisconnected;
@property(readonly) NSDate *dateUpdated;

@property(readonly) NSTimeInterval idleTime;
@property(readonly) NSTimeInterval lag;

@property(readonly) NSString *displayName;
@property(readonly) NSString *nickname;
@property(readonly) NSString *realName;
@property(readonly) NSString *username;
@property(readonly) NSString *address;
@property(readonly) NSString *serverAddress;

@property(readonly) id uniqueIdentifier;
@property(readonly) NSData *publicKey;
@property(readonly) NSString *fingerprint;

@property(readonly) NSUInteger supportedModes;
@property(readonly) NSUInteger modes;

@property(readonly) NSSet *supportedAttributes;
@property(readonly) NSDictionary *attributes;

- (BOOL) isEqual:(id) object;
- (BOOL) isEqualToChatUser:(MVChatUser *) anotherUser;

- (NSComparisonResult) compare:(MVChatUser *) otherUser;
- (NSComparisonResult) compareByNickname:(MVChatUser *) otherUser;
- (NSComparisonResult) compareByUsername:(MVChatUser *) otherUser;
- (NSComparisonResult) compareByAddress:(MVChatUser *) otherUser;
- (NSComparisonResult) compareByRealName:(MVChatUser *) otherUser;
- (NSComparisonResult) compareByIdleTime:(MVChatUser *) otherUser;

- (void) refreshInformation;

- (void) refreshAttributes;
- (void) refreshAttributeForKey:(NSString *) key;

- (BOOL) hasAttributeForKey:(NSString *) key;
- (id) attributeForKey:(NSString *) key;
- (void) setAttribute:(id) attribute forKey:(id) key;

- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action;
- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding withAttributes:(NSDictionary *) attributes;

- (void) sendCommand:(NSString *) command withArguments:(MVChatString *) arguments withEncoding:(NSStringEncoding) encoding;

- (MVUploadFileTransfer *) sendFile:(NSString *) path passively:(BOOL) passive;

- (void) sendSubcodeRequest:(NSString *) command withArguments:(id) arguments;
- (void) sendSubcodeReply:(NSString *) command withArguments:(id) arguments;
@end

#pragma mark -

#if ENABLE(SCRIPTING)
@interface MVChatUser (MVChatUserScripting)
@property(readonly) NSString *scriptUniqueIdentifier;
@property(readonly) NSScriptObjectSpecifier *objectSpecifier;
@end
#endif
