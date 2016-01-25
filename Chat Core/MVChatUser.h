#import <Foundation/Foundation.h>

#import "MVAvailability.h"
#import "MVChatString.h"


NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MVChatUserType) {
	MVChatRemoteUserType = 'remT',
	MVChatLocalUserType = 'locL',
	MVChatWildcardUserType = 'wilD'
};

typedef NS_ENUM(NSInteger, MVChatUserStatus) {
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
extern NSString *MVChatUserSSLCertFingerprintAttribute;
extern NSString *MVChatUserEmailAttribute;
extern NSString *MVChatUserPhoneAttribute;
extern NSString *MVChatUserWebsiteAttribute;
extern NSString *MVChatUserIMServiceAttribute;
extern NSString *MVChatUserCurrentlyPlayingAttribute;
extern NSString *MVChatUserStatusAttribute;
extern NSString *MVChatUserClientNameAttribute;
extern NSString *MVChatUserClientVersionAttribute;
extern NSString *MVChatUserClientUnknownAttributes;

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
+ (instancetype) wildcardUserFromString:(NSString *) mask;
+ (instancetype) wildcardUserWithNicknameMask:(NSString * __nullable) nickname andHostMask:(NSString * __nullable) host;
+ (instancetype) wildcardUserWithFingerprint:(NSString *) fingerprint;

@property(strong, readonly) MVChatConnection *connection;
@property(readonly) MVChatUserType type;

@property(readonly, getter=isRemoteUser) BOOL remoteUser;
@property(readonly, getter=isLocalUser) BOOL localUser;
@property(readonly, getter=isWildcardUser) BOOL wildcardUser;

@property(readonly, getter=isIdentified) BOOL identified;
@property(readonly, getter=isServerOperator) BOOL serverOperator;

@property(readonly) MVChatUserStatus status;
@property(strong, readonly) NSData *awayStatusMessage;

@property(strong, readonly) NSDate *dateConnected;
@property(strong, readonly) NSDate *dateDisconnected;
@property(strong, readonly) NSDate *dateUpdated;
@property(nonatomic, copy) NSDate *mostRecentUserActivity;

@property(readonly) NSTimeInterval idleTime;
@property(readonly) NSTimeInterval lag;

@property(strong, readonly) NSString *displayName;
@property(strong, readonly) NSString *nickname;
@property(strong, readonly) NSString *realName;
@property(strong, readonly) NSString *username;
@property(strong, readonly) NSString *account;
@property(strong, readonly) NSString *address;
@property(strong, readonly) NSString *serverAddress;
@property(strong, readonly) NSString *maskRepresentation;

@property(strong, readonly) id uniqueIdentifier;
@property(strong, readonly) NSData *publicKey;
@property(strong, readonly) NSString *fingerprint;

@property(readonly) NSUInteger supportedModes;
@property(readonly) NSUInteger modes;

@property(strong, readonly) NSSet *supportedAttributes;
@property(strong, readonly) NSDictionary *attributes;

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
- (void) setAttribute:(id __nullable) attribute forKey:(id) key;

- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action;
- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding withAttributes:(NSDictionary *) attributes;

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
