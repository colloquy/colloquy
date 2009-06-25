#import <SystemConfiguration/SCNetworkReachability.h>

#import <ChatCore/MVAvailability.h>
#import <ChatCore/MVChatString.h>

typedef enum {
	MVChatConnectionUnsupportedType = 0,
	MVChatConnectionICBType = 'icbC',
	MVChatConnectionIRCType = 'ircC',
	MVChatConnectionSILCType = 'silC',
	MVChatConnectionXMPPType = 'xmpC'
} MVChatConnectionType;

typedef enum {
	MVChatConnectionDisconnectedStatus = 'disC',
	MVChatConnectionServerDisconnectedStatus = 'sdsC',
	MVChatConnectionConnectingStatus = 'conG',
	MVChatConnectionConnectedStatus = 'conD',
	MVChatConnectionSuspendedStatus = 'susP'
} MVChatConnectionStatus;

typedef enum {
	MVChatConnectionNoProxy = 'nonE',
	MVChatConnectionHTTPProxy = 'httP',
	MVChatConnectionHTTPSProxy = 'htpS',
	MVChatConnectionSOCKS4Proxy = 'soK4',
	MVChatConnectionSOCKS5Proxy = 'soK5'
} MVChatConnectionProxy;

typedef enum {
	MVChatConnectionNoBouncer = 'nonB',
	MVChatConnectionGenericBouncer = 'gbnC',
	MVChatConnectionColloquyBouncer = 'cbnC'
} MVChatConnectionBouncer;

typedef enum {
	MVChatConnectionServerPublicKeyType = 'serV',
	MVChatConnectionClientPublicKeyType = 'clnT'
} MVChatConnectionPublicKeyType;

typedef enum {
	MVChatConnectionDefaultMessageFormat = 'cDtF',
	MVChatNoMessageFormat = 'nOcF',
	MVChatWindowsIRCMessageFormat = 'mIrF',
	MVChatCTCPTwoMessageFormat = 'ct2F'
} MVChatMessageFormat;

typedef enum {
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
	MVChatConnectionServicesDownError = -23
} MVChatConnectionError;

@class MVChatRoom;
@class MVChatUser;
@class MVChatUserWatchRule;
@class MVUploadFileTransfer;

extern NSString *MVChatConnectionWillConnectNotification;
extern NSString *MVChatConnectionDidConnectNotification;
extern NSString *MVChatConnectionDidNotConnectNotification;
extern NSString *MVChatConnectionWillDisconnectNotification;
extern NSString *MVChatConnectionDidDisconnectNotification;
extern NSString *MVChatConnectionErrorNotification;

extern NSString *MVChatConnectionNeedNicknamePasswordNotification;
extern NSString *MVChatConnectionNeedCertificatePasswordNotification;
extern NSString *MVChatConnectionNeedPublicKeyVerificationNotification;

extern NSString *MVChatConnectionGotBeepNotification;
extern NSString *MVChatConnectionGotImportantMessageNotification;
extern NSString *MVChatConnectionGotInformationalMessageNotification;
extern NSString *MVChatConnectionGotRawMessageNotification;
extern NSString *MVChatConnectionGotPrivateMessageNotification;
extern NSString *MVChatConnectionChatRoomListUpdatedNotification;

extern NSString *MVChatConnectionSelfAwayStatusChangedNotification;

extern NSString *MVChatConnectionNicknameAcceptedNotification;
extern NSString *MVChatConnectionNicknameRejectedNotification;

extern NSString *MVChatConnectionDidIdentifyWithServicesNotification;

extern NSString *MVChatConnectionSubcodeRequestNotification;
extern NSString *MVChatConnectionSubcodeReplyNotification;

extern NSString *MVChatConnectionErrorDomain;

@interface MVChatConnection : NSObject {
@protected
	NSMutableSet *_supportedFeatures;
	MVChatConnectionStatus _status;
	MVChatMessageFormat _outgoingChatFormat;
	NSStringEncoding _encoding;

	NSString *_npassword;
	NSMutableDictionary *_knownUsers;
	NSMutableDictionary *_knownRooms;
	NSMutableSet *_joinedRooms;
	MVChatUser *_localUser;
	NSMutableDictionary *_roomsCache;
	NSMutableSet *_chatUserWatchRules;
	NSDate *_cachedDate;
	MVChatString *_awayMessage;

	NSMutableDictionary *_persistentInformation;
	NSError *_lastError;

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
	BOOL _roomListDirty;
	BOOL _userDisconnected;

	NSDate *_lastConnectAttempt;
	NSTimer *_reconnectTimer;
	unsigned short _reconnectAttemptCount;

	NSArray *_alternateNicks;
	unsigned short _nextAltNickIndex;
	NSUInteger _hash;
}
+ (BOOL) supportsURLScheme:(NSString *) scheme;
+ (NSArray *) defaultServerPortsForType:(MVChatConnectionType) type;

#pragma mark -

- (id) initWithType:(MVChatConnectionType) type;
- (id) initWithURL:(NSURL *) url;
- (id) initWithServer:(NSString *) server type:(MVChatConnectionType) type port:(unsigned short) port user:(NSString *) nickname;

#pragma mark -

#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
@property(readonly) MVChatConnectionType type;

@property(readonly) NSSet *supportedFeatures;
@property(readonly) const NSStringEncoding *supportedStringEncodings;

@property(readonly) NSError *lastError;

@property(readonly) NSString *urlScheme;
@property(readonly) NSURL *url;

@property NSStringEncoding encoding;

@property(copy) NSString *realName;

@property(copy) NSString *nickname;
@property(copy) NSString *preferredNickname;

@property(copy) NSArray *alternateNicknames;
@property(readonly) NSString *nextAlternateNickname;

@property(copy) NSString *nicknamePassword;

@property(readonly) NSString *certificateServiceName;
@property(readonly) NSString *certificatePassword;

@property(copy) NSString *password;

@property(copy) NSString *username;

@property(copy) NSString *server;

@property unsigned short serverPort;

@property MVChatMessageFormat outgoingChatFormat;

@property(getter=isSecure) BOOL secure;

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

@property(readonly) NSSet *knownChatRooms;
@property(readonly) NSSet *joinedChatRooms;
@property(readonly) NSCharacterSet *chatRoomNamePrefixes;

@property(readonly) NSSet *knownChatUsers;
@property(readonly) MVChatUser *localUser;

@property(readonly) NSSet *chatUserWatchRules;

@property(copy) MVChatString *awayStatusMessage;

@property(readonly, getter=isConnected) BOOL connected;
@property(readonly) NSDate *connectedDate;
@property(readonly) NSDate *nextReconnectAttemptDate;
@property(readonly, getter=isWaitingToReconnect) BOOL waitingToReconnect;
@property(readonly) MVChatConnectionStatus status;
@property(readonly) NSUInteger lag;

#else

- (MVChatConnectionType) type;

#pragma mark -

- (NSSet *) supportedFeatures;
- (const NSStringEncoding *) supportedStringEncodings;

#pragma mark -

- (NSError *) lastError;

#pragma mark -

- (NSString *) urlScheme;
- (NSURL *) url;

#pragma mark -

- (void) setEncoding:(NSStringEncoding) encoding;
- (NSStringEncoding) encoding;

#pragma mark -

- (void) setRealName:(NSString *) name;
- (NSString *) realName;

#pragma mark -

- (void) setNickname:(NSString *) nickname;
- (NSString *) nickname;

- (void) setPreferredNickname:(NSString *) nickname;
- (NSString *) preferredNickname;

#pragma mark -

- (void) setAlternateNicknames:(NSArray *) nicknames;
- (NSArray *) alternateNicknames;
- (NSString *) nextAlternateNickname;

#pragma mark -

- (void) setNicknamePassword:(NSString *) password;
- (NSString *) nicknamePassword;

#pragma mark -

- (NSString *) certificateServiceName;
- (NSString *) certificatePassword;

#pragma mark -

- (void) setPassword:(NSString *) password;
- (NSString *) password;

#pragma mark -

- (void) setUsername:(NSString *) username;
- (NSString *) username;

#pragma mark -

- (void) setServer:(NSString *) server;
- (NSString *) server;

#pragma mark -

- (void) setServerPort:(unsigned short) port;
- (unsigned short) serverPort;

#pragma mark -

- (void) setOutgoingChatFormat:(MVChatMessageFormat) format;
- (MVChatMessageFormat) outgoingChatFormat;

#pragma mark -

- (void) setSecure:(BOOL) ssl;

#pragma mark -

- (void) setPersistentInformation:(NSDictionary *) information;
- (NSDictionary *) persistentInformation;

#pragma mark -

- (void) setProxyType:(MVChatConnectionProxy) type;
- (MVChatConnectionProxy) proxyType;

#pragma mark -

- (void) setProxyServer:(NSString *) address;
- (NSString *) proxyServer;

#pragma mark -

- (void) setProxyServerPort:(unsigned short) port;
- (unsigned short) proxyServerPort;

#pragma mark -

- (void) setProxyUsername:(NSString *) username;
- (NSString *) proxyUsername;

#pragma mark -

- (void) setProxyPassword:(NSString *) password;
- (NSString *) proxyPassword;

#pragma mark -

- (void) setBouncerType:(MVChatConnectionBouncer) type;
- (MVChatConnectionBouncer) bouncerType;

#pragma mark -

- (void) setBouncerServer:(NSString *) address;
- (NSString *) bouncerServer;

#pragma mark -

- (void) setBouncerServerPort:(unsigned short) port;
- (unsigned short) bouncerServerPort;

#pragma mark -

- (void) setBouncerUsername:(NSString *) username;
- (NSString *) bouncerUsername;

#pragma mark -

- (void) setBouncerPassword:(NSString *) password;
- (NSString *) bouncerPassword;

#pragma mark -

- (void) setBouncerDeviceIdentifier:(NSString *) identifier;
- (NSString *) bouncerDeviceIdentifier;

#pragma mark -

- (void) setBouncerConnectionIdentifier:(NSString *) identifier;
- (NSString *) bouncerConnectionIdentifier;

#pragma mark -

- (NSSet *) knownChatRooms;
- (NSSet *) joinedChatRooms;
- (NSCharacterSet *) chatRoomNamePrefixes;

#pragma mark -

- (NSSet *) knownChatUsers;
- (MVChatUser *) localUser;

#pragma mark -

- (NSSet *) chatUserWatchRules;

#pragma mark -

- (MVChatString *) awayStatusMessage;
- (void) setAwayStatusMessage:(MVChatString *) message;

#pragma mark -

- (MVChatConnectionStatus) status;
- (NSUInteger) lag;
#endif

#pragma mark -

- (id) persistentInformationObjectForKey:(id) key;
- (void) removePersistentInformationObjectForKey:(id) key;
- (void) setPersistentInformationObject:(id) object forKey:(id) key;

#pragma mark -

- (BOOL) isSecure;
- (BOOL) isConnected;
- (BOOL) isWaitingToReconnect;
- (NSDate *) connectedDate;
- (NSDate *) nextReconnectAttemptDate;

#pragma mark -

- (BOOL) supportsFeature:(NSString *) key;
- (BOOL) supportsStringEncoding:(NSStringEncoding) encoding;

#pragma mark -

- (void) connect;
- (void) connectToServer:(NSString *) server onPort:(unsigned short) port asUser:(NSString *) nickname;
- (void) disconnect;
- (void) disconnectWithReason:(MVChatString *) reason;

#pragma mark -

- (BOOL) authenticateCertificateWithPassword:(NSString *) password;
- (void) publicKeyVerified:(NSDictionary *) dictionary andAccepted:(BOOL) accepted andAlwaysAccept:(BOOL) alwaysAccept;

#pragma mark -

- (void) sendCommand:(NSString *) command withArguments:(MVChatString *) arguments;

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

- (void) joinChatRoomsNamed:(NSArray *) rooms;
- (void) joinChatRoomNamed:(NSString *) room;
- (void) joinChatRoomNamed:(NSString *) room withPassphrase:(NSString *) passphrase;

#pragma mark -

- (MVChatRoom *) joinedChatRoomWithUniqueIdentifier:(id) identifier;
- (MVChatRoom *) joinedChatRoomWithName:(NSString *) room;

#pragma mark -

- (MVChatRoom *) chatRoomWithUniqueIdentifier:(id) identifier;
- (MVChatRoom *) chatRoomWithName:(NSString *) room;

#pragma mark -

- (NSString *) properNameForChatRoomNamed:(NSString *) room;

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
- (NSMutableDictionary *) chatRoomListResults;

#pragma mark -

- (void) scheduleReconnectAttempt;
- (void) cancelPendingReconnectAttempts;
@end

#pragma mark -

#if ENABLE(SCRIPTING)
@interface MVChatConnection (MVChatConnectionScripting)
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
@property(readonly) NSNumber *uniqueIdentifier;
#else
- (NSNumber *) uniqueIdentifier;
#endif
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
