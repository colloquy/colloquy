#import <Foundation/Foundation.h>

#import "MVAvailability.h"
#import "MVChatString.h"
#import "MVMessaging.h"


NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(OSType, MVChatUserType) {
	MVChatRemoteUserType = 'remT',
	MVChatLocalUserType = 'locL',
	MVChatWildcardUserType = 'wilD'
};

typedef NS_ENUM(OSType, MVChatUserStatus) {
	MVChatUserUnknownStatus = 'uKnw',
	MVChatUserOfflineStatus = 'oflN',
	MVChatUserDetachedStatus = 'detA',
	MVChatUserAvailableStatus = 'avaL',
	MVChatUserAwayStatus = 'awaY'
};

typedef NS_OPTIONS(NSUInteger, MVChatUserMode) {
	MVChatUserNoModes = 0,
	MVChatUserInvisibleMode = 1 << 0
};

COLLOQUY_EXPORT extern NSString *MVChatUserKnownRoomsAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserPictureAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserPingAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserLocalTimeAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserClientInfoAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserVCardAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserServiceAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserMoodAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserStatusMessageAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserPreferredLanguageAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserPreferredContactMethodsAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserTimezoneAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserGeoLocationAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserDeviceInfoAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserExtensionAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserPublicKeyAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserServerPublicKeyAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserDigitalSignatureAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserServerDigitalSignatureAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserBanServerAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserBanAuthorAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserBanDateAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserSSLCertFingerprintAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserEmailAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserPhoneAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserWebsiteAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserIMServiceAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserCurrentlyPlayingAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserStatusAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserClientNameAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserClientVersionAttribute;
COLLOQUY_EXPORT extern NSString *MVChatUserClientUnknownAttributes;

COLLOQUY_EXPORT extern NSString *MVChatUserNicknameChangedNotification;
COLLOQUY_EXPORT extern NSString *MVChatUserStatusChangedNotification;
COLLOQUY_EXPORT extern NSString *MVChatUserAwayStatusMessageChangedNotification;
COLLOQUY_EXPORT extern NSString *MVChatUserIdleTimeUpdatedNotification;
COLLOQUY_EXPORT extern NSString *MVChatUserModeChangedNotification;
COLLOQUY_EXPORT extern NSString *MVChatUserInformationUpdatedNotification;
COLLOQUY_EXPORT extern NSString *MVChatUserAttributeUpdatedNotification;

@class MVChatConnection;
@class MVUploadFileTransfer;

COLLOQUY_EXPORT
@interface MVChatUser : NSObject <MVMessaging> {
@protected
	__weak MVChatConnection *_connection;
	id _uniqueIdentifier;
	NSString *_nickname;
	NSString *_realName;
	NSString *_username;
	NSString *_account;
	NSString *_address;
	NSString *_serverAddress;
	NSData *_publicKey;
	NSString *_fingerprint;
	NSDate *_dateConnected;
	NSDate *_dateDisconnected;
	NSDate *_dateUpdated;
	NSData *_awayStatusMessage;
	NSDate *_mostRecentUserActivity;
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
+ (MVChatUser*) wildcardUserFromString:(NSString *) mask;
+ (MVChatUser*) wildcardUserWithNicknameMask:(NSString * __nullable) nickname andHostMask:(NSString * __nullable) host;
+ (MVChatUser*) wildcardUserWithFingerprint:(NSString *) fingerprint;

@property(weak, nullable, readonly) MVChatConnection *connection;
@property(readonly) MVChatUserType type;

@property(readonly, getter=isRemoteUser) BOOL remoteUser;
@property(readonly, getter=isLocalUser) BOOL localUser;
@property(readonly, getter=isWildcardUser) BOOL wildcardUser;

@property(readonly, getter=isIdentified) BOOL identified;
@property(readonly, getter=isServerOperator) BOOL serverOperator;

@property(nonatomic, readonly) MVChatUserStatus status;
@property(copy, readonly) NSData *awayStatusMessage;

@property(copy, readonly) NSDate *dateConnected;
@property(copy, readonly) NSDate *dateDisconnected;
@property(copy, readonly) NSDate *dateUpdated;
@property(nonatomic, copy) NSDate *mostRecentUserActivity;

@property(nonatomic, readonly) NSTimeInterval idleTime;
@property(readonly) NSTimeInterval lag;

@property(copy, readonly) NSString *displayName;
@property(copy, readonly) NSString *nickname;
@property(copy, readonly) NSString *realName;
@property(copy, readonly) NSString *username;
@property(copy, readonly) NSString *account;
@property(copy, readonly) NSString *address;
@property(copy, readonly) NSString *serverAddress;
@property(copy, readonly, nullable) NSString *maskRepresentation;

@property(nonatomic, strong, readonly) id uniqueIdentifier;
@property(copy, readonly) NSData *publicKey;
@property(copy, readonly) NSString *fingerprint;

@property(readonly) NSUInteger supportedModes;
@property(readonly) NSUInteger modes;

@property(strong, readonly) NSSet<NSString*> *supportedAttributes;
@property(strong, readonly) NSDictionary<NSString*,id> *attributes;

- (BOOL) isEqual:(nullable id) object;
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
- (id __nullable) attributeForKey:(NSString *) key;
- (void) setAttribute:(id __nullable) attribute forKey:(id) key;

- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action;
- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding withAttributes:(NSDictionary<NSString*,id> *) attributes;

- (void) sendCommand:(NSString *) command withArguments:(MVChatString *) arguments withEncoding:(NSStringEncoding) encoding;

- (MVUploadFileTransfer *) sendFile:(NSString *) path passively:(BOOL) passive;

- (void) sendSubcodeRequest:(NSString *) command withArguments:(id __nullable) arguments;
- (void) sendSubcodeReply:(NSString *) command withArguments:(id __nullable) arguments;

- (void) requestRecentActivity;
- (void) persistLastActivityDate;
@end

#pragma mark -

#if ENABLE(SCRIPTING)
@interface MVChatUser (MVChatUserScripting)
@property(readonly) NSString *scriptUniqueIdentifier;
@property(readonly) NSScriptObjectSpecifier *objectSpecifier;
@end
#endif

NS_ASSUME_NONNULL_END
