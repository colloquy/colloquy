#import "MVChatConnection.h"
#import "MVChatConnectionPrivate.h"
#import "MVChatRoom.h"

NS_ASSUME_NONNULL_BEGIN

@class GCDAsyncSocket;
@class MVChatUser;
@class MVFileTransfer;

extern NSString *const MVIRCChatConnectionZNCPluginPlaybackFeature;

@interface MVIRCChatConnection : MVChatConnection {
@private
	GCDAsyncSocket *_chatConnection;
	NSDate *_queueWait;
	NSDate *_lastCommand;
	NSMutableArray *_sendQueue;
	NSMutableSet *_pendingJoinRoomNames;
	NSMutableSet *_pendingWhoisUsers;
	NSMutableSet *_directClientConnections;
	NSMutableDictionary *_serverInformation;
	NSString *_server;
	NSString *_realServer;
	NSString *_currentNickname;
	NSString *_nickname;
	NSString *_username;
	NSString *_password;
	NSString *_realName;
	NSMutableSet *_lastSentIsonNicknames;
	NSCharacterSet *_roomPrefixes;
	unsigned short _serverPort;
	unsigned short _isonSentCount;
	BOOL _sendQueueProcessing;
	BOOL _sentEndCapabilityCommand;
	NSTimeInterval _sendEndCapabilityCommandAtTime;
	BOOL _pendingIdentificationAttempt;
	NSMutableArray *_umichNoIdentdCaptcha;
	BOOL _gamesurgeGlobalBotMOTD;
	NSString *_failedNickname;
	short _failedNicknameCount;
	BOOL _nicknameShortened;
	NSMutableArray *_pendingMonitorList;
	BOOL _fetchingMonitorList;
	BOOL _monitorListFull;
	BOOL _hasRequestedPlaybackList;
}
+ (NSArray *) defaultServerPorts;
@end

#pragma mark -

@interface MVChatConnection (MVIRCChatConnectionPrivate)
@property (readonly, strong) GCDAsyncSocket *_chatConnection;
- (void) _connect;

- (void) _readNextMessageFromServer;
- (void) _processIncomingMessage:(NSData *) data fromServer:(BOOL) fromServer;
- (void) _writeDataToServer:(id) raw;

- (void) _handleCTCP:(NSMutableData *) data asRequest:(BOOL) request fromSender:(MVChatUser *) sender toTarget:(id) target forRoom:(MVChatRoom *) room;

+ (NSData *) _flattenedIRCDataForMessage:(MVChatString *) message withEncoding:(NSStringEncoding) enc andChatFormat:(MVChatMessageFormat) format;
- (void) _sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) msgEncoding toTarget:(id) target withTargetPrefix:(NSString *) targetPrefix withAttributes:(NSDictionary *) attributes localEcho:(BOOL) echo;
- (void) _sendCommand:(NSString *) command withArguments:(MVChatString *) arguments withEncoding:(NSStringEncoding) encoding toTarget:(id __nullable) target;

- (void) sendBrokenDownMessage:(NSMutableData *) msg withPrefix:(NSString *) prefix withEncoding:(NSStringEncoding) msgEncoding withMaximumBytes:(NSUInteger) bytesLeft;
- (NSUInteger) bytesRemainingForMessage:(NSString *) nickname withUsername:(NSString *) username withAddress:(NSString *) address withPrefix:(NSString *) prefix withEncoding:(NSStringEncoding) msgEncoding;
- (BOOL) validCharacterToSend:(char *) lastCharacter whitespaceInString:(BOOL) hasWhitespaceInString;

- (void) _updateKnownUser:(MVChatUser *) user withNewNickname:(NSString *) nickname;

- (void) _addDirectClientConnection:(id) connection;
- (void) _removeDirectClientConnection:(id) connection;

- (void) _setCurrentNickname:(NSString *) nickname;
- (void) _handleConnect;
- (void) _identifyWithServicesUsingNickname:(NSString *) nickname;

- (void) _periodicCleanUp;
- (void) _startSendQueue;
- (void) _stopSendQueue;
- (void) _resetSendQueueInterval;

- (void) _scheduleWhoisForUser:(MVChatUser *) user;
- (void) _whoisNextScheduledUser;

- (void) _resetSupportedFeatures;

@property (readonly, copy) NSCharacterSet *_nicknamePrefixes;
- (MVChatRoomMemberMode) _modeForNicknamePrefixCharacter:(unichar) character;
- (MVChatRoomMemberMode) _stripModePrefixesFromNickname:(NSString *__nonnull *__nonnull) nickname;

- (NSString *) _newStringWithBytes:(const char *) bytes length:(NSUInteger) length NS_RETURNS_RETAINED;
- (NSString *) _stringFromPossibleData:(id) input;

- (void) _cancelScheduledSendEndCapabilityCommand;
- (void) _sendEndCapabilityCommandAfterTimeout;
- (void) _sendEndCapabilityCommandSoon;
- (void) _sendEndCapabilityCommand;
@end

NS_ASSUME_NONNULL_END
