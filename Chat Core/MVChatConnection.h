typedef enum {
	MVChatConnectionIRCType = 'ircC',
	MVChatConnectionSILCType = 'silC'
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
	MVChatConnectionSOCKSProxy = 'sokS'
} MVChatConnectionProxy;

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
	MVChatConnectionNoSuchUserError = -1,
	MVChatConnectionNoSuchRoomError = -2,
	MVChatConnectionNoSuchServerError = -3,
	MVChatConnectionCantSendToRoomError = -4,
	MVChatConnectionNotInRoomError = -5,
	MVChatConnectionUserNotInRoomError = -6,
	MVChatConnectionRoomIsFullError = -7,
	MVChatConnectionInviteOnlyRoomError = -8,
	MVChatConnectionRoomPasswordIncorrectError = -9,
	MVChatConnectionBannedFromRoomError = -10,
	MVChatConnectionUnknownCommandError = -11,
	MVChatConnectionErroneusNicknameError = -12,
	MVChatConnectionBannedFromServerError = -13,
	MVChatConnectionServerPasswordIncorrectError = -14
} MVChatConnectionError;

@class MVChatRoom;
@class MVChatUser;
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

extern NSString *MVChatConnectionGotRawMessageNotification;
extern NSString *MVChatConnectionGotPrivateMessageNotification;
extern NSString *MVChatConnectionChatRoomListUpdatedNotification;

extern NSString *MVChatConnectionSelfAwayStatusChangedNotification;

extern NSString *MVChatConnectionWatchedUserOnlineNotification;
extern NSString *MVChatConnectionWatchedUserOfflineNotification;

extern NSString *MVChatConnectionNicknameAcceptedNotification;
extern NSString *MVChatConnectionNicknameRejectedNotification;

extern NSString *MVChatConnectionSubcodeRequestNotification;
extern NSString *MVChatConnectionSubcodeReplyNotification;

extern NSString *MVChatConnectionErrorDomain;

@interface MVChatConnection : NSObject {
@protected
	MVChatConnectionStatus _status;
	MVChatConnectionProxy _proxy;
	MVChatMessageFormat _outgoingChatFormat;
	NSStringEncoding _encoding;

	NSString *_npassword;
	NSMutableSet *_joinedRooms;
	MVChatUser *_localUser;
	NSMutableDictionary *_roomsCache;
	NSDate *_cachedDate;
	NSDate *_lastConnectAttempt;
	NSTimer *_reconnectTimer;
	NSAttributedString *_awayMessage;
	NSMutableDictionary *_persistentInformation;
	NSError *_lastError;

	NSArray *_alternateNicks;
	unsigned int _nextAltNickIndex;
	BOOL _roomListDirty;
}
+ (BOOL) supportsURLScheme:(NSString *) scheme;
+ (NSArray *) defaultServerPortsForType:(MVChatConnectionType) type;

#pragma mark -

- (id) initWithType:(MVChatConnectionType) type;
- (id) initWithURL:(NSURL *) url;
- (id) initWithServer:(NSString *) server type:(MVChatConnectionType) type port:(unsigned short) port user:(NSString *) nickname;

#pragma mark -

- (MVChatConnectionType) type;

#pragma mark -

- (NSSet *) supportedFeatures;
- (BOOL) supportsFeature:(NSString *) key;

#pragma mark -

- (const NSStringEncoding *) supportedStringEncodings;
- (BOOL) supportsStringEncoding:(NSStringEncoding) encoding;

#pragma mark -

- (void) connect;
- (void) connectToServer:(NSString *) server onPort:(unsigned short) port asUser:(NSString *) nickname;
- (void) disconnect;
- (void) disconnectWithReason:(NSAttributedString *) reason;

#pragma mark -

- (NSError *) lastError;

#pragma mark -

- (NSString *) urlScheme;
- (NSURL *) url;

#pragma mark -

- (void) setEncoding:(NSStringEncoding) encoding;
- (NSStringEncoding) encoding;
- (NSString *) stringWithEncodedBytes:(const char *) bytes;
- (NSString *) stringWithEncodedBytesNoCopy:(char *) bytes freeWhenDone:(BOOL) free;
- (const char *) encodedBytesWithString:(NSString *) string;

#pragma mark -

- (void) setRealName:(NSString *) name;
- (NSString *) realName;

- (void) setNickname:(NSString *) nickname;
- (NSString *) nickname;
- (NSString *) preferredNickname;

- (void) setAlternateNicknames:(NSArray *) nicknames;
- (NSArray *) alternateNicknames;
- (NSString *) nextAlternateNickname;

- (void) setNicknamePassword:(NSString *) password;
- (NSString *) nicknamePassword;

- (NSString *) certificateServiceName;
- (BOOL) setCertificatePassword:(NSString *) password;
- (NSString *) certificatePassword;

- (void) setPassword:(NSString *) password;
- (NSString *) password;

- (void) setUsername:(NSString *) username;
- (NSString *) username;

- (void) setServer:(NSString *) server;
- (NSString *) server;

- (void) setServerPort:(unsigned short) port;
- (unsigned short) serverPort;

- (void) setOutgoingChatFormat:(MVChatMessageFormat) format;
- (MVChatMessageFormat) outgoingChatFormat;

- (void) setProxyUsername:(NSString *) username;
- (NSString *) proxyUsername;

- (void) setProxyPassword:(NSString *) password;
- (NSString *) proxyPassword;

- (void) setSecure:(BOOL) ssl;
- (BOOL) isSecure;

- (void) setPersistentInformation:(NSDictionary *) information;
- (NSDictionary *) persistentInformation;

- (void) publicKeyVerified:(NSDictionary *) dictionary andAccepted:(BOOL) accepted andAlwaysAccept:(BOOL) alwaysAccept;

#pragma mark -

- (void) setProxyType:(MVChatConnectionProxy) type;
- (MVChatConnectionProxy) proxyType;

- (void) setProxyServer:(NSString *) address;
- (NSString *) proxyServer;

- (void) setProxyServerPort:(unsigned short) port;
- (unsigned short) proxyServerPort;

#pragma mark -

- (void) sendRawMessage:(NSString *) raw;
- (void) sendRawMessage:(NSString *) raw immediately:(BOOL) now;
- (void) sendRawMessageWithFormat:(NSString *) format, ...;

#pragma mark -

- (void) joinChatRoomsNamed:(NSArray *) rooms;
- (void) joinChatRoomNamed:(NSString *) room;
- (void) joinChatRoomNamed:(NSString *) room withPassphrase:(NSString *) passphrase;

#pragma mark -

- (NSSet *) joinedChatRooms;
- (MVChatRoom *) joinedChatRoomWithName:(NSString *) room;

#pragma mark -

- (NSCharacterSet *) chatRoomNamePrefixes;
- (NSString *) properNameForChatRoomNamed:(NSString *) room;

#pragma mark -

- (NSSet *) knownChatUsers;
- (NSSet *) chatUsersWithNickname:(NSString *) nickname;
- (NSSet *) chatUsersWithFingerprint:(NSString *) fingerprint;
- (MVChatUser *) chatUserWithUniqueIdentifier:(id) identifier;
- (MVChatUser *) localUser;

#pragma mark -

- (void) startWatchingUser:(MVChatUser *) user;
- (void) stopWatchingUser:(MVChatUser *) user;

#pragma mark -

- (void) fetchChatRoomList;
- (void) stopFetchingChatRoomList;
- (NSMutableDictionary *) chatRoomListResults;

#pragma mark -

- (NSAttributedString *) awayStatusMessage;
- (void) setAwayStatusWithMessage:(NSAttributedString *) message;
- (void) clearAwayStatus;

#pragma mark -

- (BOOL) isConnected;
- (MVChatConnectionStatus) status;
- (unsigned int) lag;

#pragma mark -

- (void) scheduleReconnectAttemptEvery:(NSTimeInterval) seconds;
- (void) cancelPendingReconnectAttempts;
- (BOOL) isWaitingToReconnect;
@end

#pragma mark -

@interface MVChatConnection (MVChatConnectionScripting)
- (NSNumber *) uniqueIdentifier;
@end

#pragma mark -

@interface NSObject (MVChatPluginConnectionSupport)
- (BOOL) processSubcodeRequest:(NSString *) command withArguments:(NSString *) arguments fromUser:(MVChatUser *) user;
- (BOOL) processSubcodeReply:(NSString *) command withArguments:(NSString *) arguments fromUser:(MVChatUser *) user;

- (void) connected:(MVChatConnection *) connection;
- (void) disconnecting:(MVChatConnection *) connection;
@end