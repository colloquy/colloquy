#import "MVChatConnection.h"
#import "MVChatConnectionPrivate.h"
#import "MVChatRoom.h"

@class AsyncSocket;
@class MVChatUser;
@class MVFileTransfer;

@interface MVIRCChatConnection : MVChatConnection {
@private
	AsyncSocket *_chatConnection;
	NSTimer *_periodicCleanUpTimer;
	NSThread *_connectionThread;
	NSDate *_queueWait;
	NSDate *_lastCommand;
	NSMutableArray *_sendQueue;
	NSMutableDictionary *_knownUsers;
	NSMutableSet *_pendingWhoisUsers;
	NSMutableSet *_directClientConnections;
	NSMutableDictionary *_serverInformation;
	NSString *_server;
	NSString *_currentNickname;
	NSString *_nickname;
	NSString *_username;
	NSString *_password;
	NSString *_realName;
	NSMutableSet *_lastSentIsonNicknames;
	NSCharacterSet *_roomPrefixes;
	NSConditionLock *_threadWaitLock;
	unsigned short _serverPort;
	unsigned short _isonSentCount;
	BOOL _watchCommandSupported;
	BOOL _sendQueueProcessing;
}
+ (NSArray *) defaultServerPorts;
@end

#pragma mark -

@interface MVChatConnection (MVIRCChatConnectionPrivate)
- (AsyncSocket *) _chatConnection;
- (void) _readNextMessageFromServer;

- (void) _handleCTCP:(NSMutableData *) data asRequest:(BOOL) request fromSender:(MVChatUser *) sender forRoom:(MVChatRoom *) room;

+ (NSData *) _flattenedIRCDataForMessage:(MVChatString *) message withEncoding:(NSStringEncoding) enc andChatFormat:(MVChatMessageFormat) format;
- (void) _sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) msgEncoding toTarget:(id) target withTargetPrefix:(NSString *) targetPrefix withAttributes:(NSDictionary *) attributes localEcho:(BOOL) echo;
- (void) _sendCommand:(NSString *) command withArguments:(MVChatString *) arguments withEncoding:(NSStringEncoding) encoding toTarget:(id) target;

- (void) _processErrorCode:(int) errorCode withContext:(char *) context;

- (void) _updateKnownUser:(MVChatUser *) user withNewNickname:(NSString *) nickname;

- (void) _addDirectClientConnection:(id) connection;
- (void) _removeDirectClientConnection:(id) connection;

- (void) _setCurrentNickname:(NSString *) nickname;

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

- (NSString *) _newStringWithBytes:(const char *) bytes length:(unsigned) length;
- (NSString *) _stringFromPossibleData:(id) input;
@end
