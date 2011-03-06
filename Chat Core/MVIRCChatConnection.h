#import "MVChatConnection.h"
#import "MVChatConnectionPrivate.h"
#import "MVChatRoom.h"

@class AsyncSocket;
@class MVChatUser;
@class MVFileTransfer;

@interface MVIRCChatConnection : MVChatConnection {
@private
	AsyncSocket *_chatConnection;
	NSThread *_connectionThread;
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
	BOOL _watchCommandSupported;
	BOOL _sendQueueProcessing;
	BOOL _sentEndCapabilityCommand;
	BOOL _pendingIdentificationAttempt;
	NSMutableArray *_umichNoIdentdCaptcha;
	NSString *_failedNickname;
	NSInteger _failedNicknameCount;
	BOOL _nicknameShortened;
}
+ (NSArray *) defaultServerPorts;
@end

#pragma mark -

@interface MVChatConnection (MVIRCChatConnectionPrivate)
- (AsyncSocket *) _chatConnection;
- (void) _readNextMessageFromServer;
- (void) _processIncomingMessage:(NSData *) data fromServer:(BOOL) fromServer;

- (void) _handleCTCP:(NSMutableData *) data asRequest:(BOOL) request fromSender:(MVChatUser *) sender toTarget:(id) target forRoom:(MVChatRoom *) room;

+ (NSData *) _flattenedIRCDataForMessage:(MVChatString *) message withEncoding:(NSStringEncoding) enc andChatFormat:(MVChatMessageFormat) format;
- (void) _sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) msgEncoding toTarget:(id) target withTargetPrefix:(NSString *) targetPrefix withAttributes:(NSDictionary *) attributes localEcho:(BOOL) echo;
- (void) _sendCommand:(NSString *) command withArguments:(MVChatString *) arguments withEncoding:(NSStringEncoding) encoding toTarget:(id) target;

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

- (NSCharacterSet *) _nicknamePrefixes;
- (MVChatRoomMemberMode) _modeForNicknamePrefixCharacter:(unichar) character;
- (MVChatRoomMemberMode) _stripModePrefixesFromNickname:(NSString **) nickname;

- (NSString *) _newStringWithBytes:(const char *) bytes length:(NSUInteger) length;
- (NSString *) _stringFromPossibleData:(id) input;

- (void) _cancelScheduledSendEndCapabilityCommand;
- (void) _sendEndCapabilityCommandAfterTimeout;
- (void) _sendEndCapabilityCommand;
@end
