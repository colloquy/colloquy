#import "MVChatConnection.h"
#import "MVChatConnectionPrivate.h"

@class AsyncSocket;
@class MVChatUser;
@class MVChatRoom;
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
	NSMutableSet *_fileTransfers;
	NSMutableSet *_supportedFeatures;
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
	BOOL _watchCommandSupported : 1;
	BOOL _sendQueueProcessing : 1;
}
+ (NSArray *) defaultServerPorts;
@end

#pragma mark -

@interface MVChatConnection (MVIRCChatConnectionPrivate)
- (AsyncSocket *) _chatConnection;
- (void) _readNextMessageFromServer;

- (void) _handleCTCP:(NSMutableData *) data asRequest:(BOOL) request fromSender:(MVChatUser *) sender forRoom:(MVChatRoom *) room;
	
+ (NSData *) _flattenedIRCDataForMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) enc andChatFormat:(MVChatMessageFormat) format;
- (void) _sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding toTarget:(NSString *) target asAction:(BOOL) action;

- (void) _processErrorCode:(int) errorCode withContext:(char *) context;

- (void) _updateKnownUser:(MVChatUser *) user withNewNickname:(NSString *) nickname;

- (void) _addFileTransfer:(MVFileTransfer *) transfer;
- (void) _removeFileTransfer:(MVFileTransfer *) transfer;

- (void) _setCurrentNickname:(NSString *) nickname;

- (void) _periodicCleanUp;
- (void) _startSendQueue;
- (void) _stopSendQueue;
- (void) _resetSendQueueInterval;

- (void) _scheduleWhoisForUser:(MVChatUser *) user;
- (void) _whoisNextScheduledUser;

- (void) _resetSupportedFeatures;

- (NSString *) _newStringWithBytes:(const char *) bytes length:(unsigned) length;
- (NSString *) _stringFromPossibleData:(id) input;
@end
