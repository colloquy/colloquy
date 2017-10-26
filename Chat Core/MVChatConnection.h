#import <Foundation/Foundation.h>
#include <SystemConfiguration/SCNetworkReachability.h>

#import <ChatCore/MVAvailability.h>
#import <ChatCore/MVChatString.h>


NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(OSType, MVChatConnectionType) {
	MVChatConnectionUnsupportedType = 0,
	MVChatConnectionICBType = 'icbC',
	MVChatConnectionIRCType = 'ircC',
	MVChatConnectionSILCType = 'silC',
	MVChatConnectionXMPPType = 'xmpC'
};

typedef NS_ENUM(OSType, MVChatConnectionStatus) {
	MVChatConnectionDisconnectedStatus = 'disC',
	MVChatConnectionServerDisconnectedStatus = 'sdsC',
	MVChatConnectionConnectingStatus = 'conG',
	MVChatConnectionConnectedStatus = 'conD',
	MVChatConnectionSuspendedStatus = 'susP'
};

typedef NS_ENUM(OSType, MVChatConnectionProxy) {
	MVChatConnectionNoProxy = 'nonE',
	MVChatConnectionHTTPProxy = 'httP',
	MVChatConnectionHTTPSProxy = 'htpS',
	MVChatConnectionSOCKS4Proxy = 'soK4',
	MVChatConnectionSOCKS5Proxy = 'soK5'
};

typedef NS_ENUM(OSType, MVChatConnectionBouncer) {
	MVChatConnectionNoBouncer = 'nonB',
	MVChatConnectionGenericBouncer = 'gbnC',
	MVChatConnectionColloquyBouncer = 'cbnC'
};

typedef NS_ENUM(OSType, MVChatConnectionPublicKeyType) {
	MVChatConnectionServerPublicKeyType = 'serV',
	MVChatConnectionClientPublicKeyType = 'clnT'
};

typedef NS_ENUM(OSType, MVChatMessageFormat) {
	MVChatConnectionDefaultMessageFormat = 'cDtF',
	MVChatNoMessageFormat = 'nOcF',
	MVChatWindowsIRCMessageFormat = 'mIrF',
	MVChatCTCPTwoMessageFormat = 'ct2F',
	MVChatJSONMessageFormat = 'jsoN'
};

typedef NS_ENUM(NSInteger, MVChatConnectionError) {
	MVChatConnectionUnknownError = -1,
	MVChatConnectionNoSuchUserError = -2,
	MVChatConnectionNoSuchRoomError = -3,
	MVChatConnectionNoSuchServerError = -4,
	MVChatConnectionCantSendToRoomError = -5,
	MVChatConnectionCantChangeNickError = -6,
	MVChatConnectionNotInRoomError = -7,
	MVChatConnectionUserNotInRoomError = -8,
	MVChatConnectionRoomIsFullError = -9,
	MVChatConnectionInviteOnlyRoomError = -10,
	MVChatConnectionRoomPasswordIncorrectError = -11,
	MVChatConnectionBannedFromRoomError = -12,
	MVChatConnectionUnknownCommandError = -13,
	MVChatConnectionErroneusNicknameError = -14,
	MVChatConnectionBannedFromServerError = -15,
	MVChatConnectionServerPasswordIncorrectError = -16,
	MVChatConnectionProtocolError = -17,
	MVChatConnectionOutOfBricksError = -18,
	MVChatConnectionCantChangeUsedNickError = -19,
	MVChatConnectionIdentifyToJoinRoomError = -20,
	MVChatConnectionRoomDoesNotSupportModesError = -21,
	MVChatConnectionNickChangedByServicesError = -22,
	MVChatConnectionServicesDownError = -23,
	MVChatConnectionTLSError = -24
};

typedef BOOL (^MVPeerTrustHandler)(SecTrustRef);

@class MVChatRoom;
@class MVChatUser;
@class MVChatUserWatchRule;

COLLOQUY_EXPORT extern NSString *MVChatConnectionWatchFeature;

// IRC3v1 Required
COLLOQUY_EXPORT extern NSString *MVChatConnectionSASLFeature;
COLLOQUY_EXPORT extern NSString *MVChatConnectionMultipleNicknamePrefixFeature;

// IRC3v1 Optional
COLLOQUY_EXPORT extern NSString *MVChatConnectionAccountNotifyFeature;
COLLOQUY_EXPORT extern NSString *MVChatConnectionAwayNotifyFeature;
COLLOQUY_EXPORT extern NSString *MVChatConnectionExtendedJoinFeature;
COLLOQUY_EXPORT extern NSString *MVChatConnectionTLSFeature;

// IRC3v2 Required
COLLOQUY_EXPORT extern NSString *MVChatConnectionMessageTagsFeature;
COLLOQUY_EXPORT extern NSString *MVChatConnectionMonitorFeature;

// IRC3v2 Optional
COLLOQUY_EXPORT extern NSString *MVChatConnectionServerTimeFeature;
COLLOQUY_EXPORT extern NSString *MVChatConnectionBatchFeature;
COLLOQUY_EXPORT extern NSString *MVChatConnectionUserhostInNamesFeature;
COLLOQUY_EXPORT extern NSString *MVChatConnectionChghostFeature;

COLLOQUY_EXPORT extern NSString *MVChatConnectionAccountTagFeature;
COLLOQUY_EXPORT extern NSString *MVChatConnectionCapNotifyFeature;
COLLOQUY_EXPORT extern NSString *MVChatConnectionInviteFeature;
COLLOQUY_EXPORT extern NSString *MVChatConnectionEchoMessageFeature;

// IRC3v3 Prototypes
COLLOQUY_EXPORT extern NSString *MVChatConnectionSTSFeature;

// InspIRCd Enhancements
COLLOQUY_EXPORT extern NSString *MVChatConnectionNamesxFeature;

// Notifications
COLLOQUY_EXPORT extern NSString *MVChatConnectionWillConnectNotification;
COLLOQUY_EXPORT extern NSString *MVChatConnectionDidConnectNotification;
COLLOQUY_EXPORT extern NSString *MVChatConnectionDidNotConnectNotification;
COLLOQUY_EXPORT extern NSString *MVChatConnectionWillDisconnectNotification;
COLLOQUY_EXPORT extern NSString *MVChatConnectionDidDisconnectNotification;
COLLOQUY_EXPORT extern NSString *MVChatConnectionGotErrorNotification;
COLLOQUY_EXPORT extern NSString *MVChatConnectionErrorNotification;

COLLOQUY_EXPORT extern NSString *MVChatConnectionNeedTLSPeerTrustFeedbackNotification; // used when connecting
COLLOQUY_EXPORT extern NSString *MVChatConnectionNeedNicknamePasswordNotification;
COLLOQUY_EXPORT extern NSString *MVChatConnectionNeedServerPasswordNotification;
COLLOQUY_EXPORT extern NSString *MVChatConnectionNeedCertificatePasswordNotification;
COLLOQUY_EXPORT extern NSString *MVChatConnectionNeedPublicKeyVerificationNotification;

COLLOQUY_EXPORT extern NSString *MVChatConnectionGotBeepNotification;
COLLOQUY_EXPORT extern NSString *MVChatConnectionGotImportantMessageNotification;
COLLOQUY_EXPORT extern NSString *MVChatConnectionGotInformationalMessageNotification;
COLLOQUY_EXPORT extern NSString *MVChatConnectionGotRawMessageNotification;
COLLOQUY_EXPORT extern NSString *MVChatConnectionGotPrivateMessageNotification;
COLLOQUY_EXPORT extern NSString *MVChatConnectionChatRoomListUpdatedNotification;
COLLOQUY_EXPORT extern NSString *MVChatConnectionBatchUpdatesWillBeginNotification;
COLLOQUY_EXPORT extern NSString *MVChatConnectionBatchUpdatesDidEndNotification;

COLLOQUY_EXPORT extern NSString *MVChatConnectionSelfAwayStatusChangedNotification;

COLLOQUY_EXPORT extern NSString *MVChatConnectionNicknameAcceptedNotification;
COLLOQUY_EXPORT extern NSString *MVChatConnectionNicknameRejectedNotification;

COLLOQUY_EXPORT extern NSString *MVChatConnectionDidIdentifyWithServicesNotification;

COLLOQUY_EXPORT extern NSString *MVChatConnectionSubcodeRequestNotification;
COLLOQUY_EXPORT extern NSString *MVChatConnectionSubcodeReplyNotification;

extern NSString *MVChatConnectionErrorDomain;

COLLOQUY_EXPORT
@interface MVChatConnection : NSObject {
@protected
	NSMutableSet *_supportedFeatures;
	MVChatConnectionStatus _status;
	NSStringEncoding _encoding;

	NSString *_uniqueIdentifier;

	NSMapTable *_knownUsers;
	NSMutableDictionary *_knownRooms;
	NSMutableSet *_joinedRooms;
	MVChatUser *_localUser;
	NSMutableDictionary *_roomsCache;
	NSMutableSet *_pendingRoomAdditions;
	NSMutableSet *_pendingRoomUpdates;
	NSMutableSet *_chatUserWatchRules;
	NSDate *_cachedDate;
	MVChatString *_awayMessage;

	NSMutableDictionary *_persistentInformation;
	NSError *_lastError; // socket errors
	NSError *_serverError; // messages from the server

	SCNetworkReachabilityRef _reachability;

	NSDate *_connectedDate;

	MVChatConnectionProxy _proxy;
	NSString *_proxyServer;
	NSString *_proxyUsername;
	NSString *_proxyPassword;
	unsigned short _proxyServerPort;

	MVChatConnectionBouncer _bouncer;
	NSString *_bouncerServer;
	NSString *_bouncerUsername;
	NSString *_bouncerPassword;
	NSString *_bouncerDeviceIdentifier;
	NSString *_bouncerConnectionIdentifier;
	unsigned short _bouncerServerPort;

	BOOL _secure;
	BOOL _connectedSecurely;
	BOOL _requestsSASL;
	BOOL _roomsWaitForIdentification;
	BOOL _roomListDirty;
	BOOL _userDisconnected;

	NSDate *_lastConnectAttempt;
	NSTimer *_reconnectTimer;
	unsigned short _reconnectAttemptCount;

	NSArray <NSString *> *_alternateNicks;
	unsigned short _nextAltNickIndex;
	NSUInteger _hash;
}
+ (BOOL) supportsURLScheme:(NSString *__nullable) scheme;
+ (NSArray <NSNumber *> *) defaultServerPortsForType:(MVChatConnectionType) type;
+ (NSUInteger) maxMessageLengthForType:(MVChatConnectionType) type;

#pragma mark -

- (instancetype) initWithType:(MVChatConnectionType) type;
- (instancetype) initWithURL:(NSURL *) url;
- (instancetype) initWithServer:(NSString *) server type:(MVChatConnectionType) type port:(unsigned short) port user:(NSString *) nickname;

#pragma mark -

@property(readonly) MVChatConnectionType type;

@property(copy) NSString *uniqueIdentifier;

@property(strong, readonly) NSSet *supportedFeatures;
@property(readonly) const NSStringEncoding *supportedStringEncodings;

@property(strong, readonly) NSError *lastError;
@property(strong, readonly) NSError *serverError;

@property(strong, readonly) NSString *urlScheme;
@property(strong, readonly) NSURL *url;

@property NSStringEncoding encoding;

@property(copy, nullable) NSString *realName;

@property(copy, nullable) NSString *nickname;
@property(copy) NSString *preferredNickname;

@property(copy, nullable) NSArray <NSString *> *alternateNicknames;
@property(strong, readonly, nullable) NSString *nextAlternateNickname;

@property(copy, nullable) NSString *nicknamePassword;

@property(strong, readonly, nullable) NSString *certificateServiceName;
@property(strong, readonly, nullable) NSString *certificatePassword;

@property(copy, nullable) NSString *password;

@property(copy, nullable) NSString *username;

@property(copy) NSString *server;
- (void)setServer:(NSString * _Nonnull)server NS_REQUIRES_SUPER;

@property unsigned short serverPort;

@property(nonatomic) MVChatMessageFormat incomingChatFormat;
@property(nonatomic) MVChatMessageFormat outgoingChatFormat;

@property(getter=didConnectSecurely) BOOL connectedSecurely; // IRCv3.1 + `tls` capability can indicate that the *next* connection will be secure, but not our current one
@property(getter=isSecure) BOOL secure;
@property BOOL requestsSASL;
@property BOOL roomsWaitForIdentification;

@property(copy) NSDictionary *persistentInformation;

@property MVChatConnectionProxy proxyType;
@property(copy) NSString *proxyServer;
@property unsigned short proxyServerPort;
@property(copy) NSString *proxyUsername;
@property(copy) NSString *proxyPassword;

@property MVChatConnectionBouncer bouncerType;
@property(copy) NSString *bouncerServer;
@property unsigned short bouncerServerPort;
@property(copy) NSString *bouncerUsername;
@property(copy) NSString *bouncerPassword;
@property(copy) NSString *bouncerDeviceIdentifier;
@property(copy) NSString *bouncerConnectionIdentifier;

@property(strong, readonly) NSSet *knownChatRooms;
@property(strong, readonly) NSSet *joinedChatRooms;
@property(strong, readonly) NSCharacterSet *chatRoomNamePrefixes;

@property(strong, readonly) NSSet *knownChatUsers;
@property(strong, readonly) MVChatUser *localUser;

@property(strong, readonly) NSSet *chatUserWatchRules;

@property(copy, null_resettable) MVChatString *awayStatusMessage;

@property(readonly, getter=isConnected) BOOL connected;
@property(strong, readonly) NSDate *connectedDate;
@property(strong, readonly) NSDate *nextReconnectAttemptDate;
@property(readonly, getter=isWaitingToReconnect) BOOL waitingToReconnect;
@property(readonly) unsigned short reconnectAttemptCount;
@property(readonly) MVChatConnectionStatus status;
@property(readonly) NSUInteger lag;

#pragma mark -

- (id) persistentInformationObjectForKey:(id) key;
- (void) removePersistentInformationObjectForKey:(id) key;
- (void) setPersistentInformationObject:(id) object forKey:(id) key;

#pragma mark -

- (unsigned short) reconnectAttemptCount;
- (NSDate *) connectedDate;
- (NSDate *) nextReconnectAttemptDate;

#pragma mark -

- (BOOL) supportsFeature:(NSString *) key;
- (BOOL) supportsStringEncoding:(NSStringEncoding) encoding;

#pragma mark -

- (void) connect;
- (void) connectToServer:(NSString *) server onPort:(unsigned short) port asUser:(NSString *) nickname;
- (void) disconnect;
- (void) disconnectWithReason:(MVChatString * __nullable) reason;
- (void) forceDisconnect;

#pragma mark -

- (BOOL) authenticateCertificateWithPassword:(NSString *) password;
- (void) publicKeyVerified:(NSDictionary *) dictionary andAccepted:(BOOL) accepted andAlwaysAccept:(BOOL) alwaysAccept;

#pragma mark -

- (void) sendCommand:(NSString *) command withArguments:(MVChatString * __nullable) arguments;

#pragma mark -

- (void) sendRawMessage:(id) raw;
- (void) sendRawMessage:(id) raw immediately:(BOOL) now;
- (void) sendRawMessageWithFormat:(NSString *) format, ...;
- (void) sendRawMessageImmediatelyWithFormat:(NSString *) format, ...;
- (void) sendRawMessageWithComponents:(id) firstComponent, ...;
- (void) sendRawMessageImmediatelyWithComponents:(id) firstComponent, ...;

#pragma mark -

- (void) processIncomingMessage:(id) raw;
- (void) processIncomingMessage:(id) raw fromServer:(BOOL) fromServer;

#pragma mark -

- (void) joinChatRoomsNamed:(NSArray <NSString *> *) rooms;
- (void) joinChatRoomNamed:(NSString *) room;
- (void) joinChatRoomNamed:(NSString *) room withPassphrase:(NSString * __nullable) passphrase;

#pragma mark -

- (MVChatRoom *) joinedChatRoomWithUniqueIdentifier:(id) identifier;
- (MVChatRoom *) joinedChatRoomWithName:(NSString *) room;

#pragma mark -

- (MVChatRoom *) chatRoomWithUniqueIdentifier:(id) identifier;
- (MVChatRoom *__nullable) chatRoomWithName:(NSString *) room;

#pragma mark -

- (NSString *) properNameForChatRoomNamed:(NSString *) room;
- (NSString *) displayNameForChatRoomNamed:(NSString *) room;

#pragma mark -

- (NSSet *) chatUsersWithNickname:(NSString *) nickname;
- (NSSet *) chatUsersWithFingerprint:(NSString *) fingerprint;
- (MVChatUser *) chatUserWithUniqueIdentifier:(id) identifier;

#pragma mark -

- (void) addChatUserWatchRule:(MVChatUserWatchRule *) rule;
- (void) removeChatUserWatchRule:(MVChatUserWatchRule *) rule;

#pragma mark -

- (void) fetchChatRoomList;
- (void) stopFetchingChatRoomList;
@property (readonly, copy) NSMutableDictionary *chatRoomListResults;

#pragma mark -

- (void) scheduleReconnectAttempt;
- (void) cancelPendingReconnectAttempts;

#pragma mark -

- (void) purgeCaches;
@end

#pragma mark -

#if ENABLE(SCRIPTING)
@interface MVChatConnection (MVChatConnectionScripting)
@property(readonly) NSNumber *scriptUniqueIdentifier;
@end
#endif

#pragma mark -

@interface NSObject (MVChatPluginConnectionSupport)
- (void) processIncomingMessageAsData:(NSMutableData *) message from:(MVChatUser *) sender to:(id) receiver attributes:(NSMutableDictionary *)msgAttributes;
- (void) processOutgoingMessageAsData:(NSMutableData *) message to:(id) receiver attributes:(NSDictionary *)msgAttributes;

- (void) processTopicAsData:(NSMutableData *) topic inRoom:(MVChatRoom *) room author:(MVChatUser *) author;

- (BOOL) processSubcodeRequest:(NSString *) command withArguments:(NSData *) arguments fromUser:(MVChatUser *) user;
- (BOOL) processSubcodeReply:(NSString *) command withArguments:(NSData *) arguments fromUser:(MVChatUser *) user;

- (void) connected:(MVChatConnection *) connection;
- (void) disconnecting:(MVChatConnection *) connection;
@end

NS_ASSUME_NONNULL_END
