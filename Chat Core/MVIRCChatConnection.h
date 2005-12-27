#import "MVChatConnection.h"
#import "MVChatConnectionPrivate.h"

@class AsyncSocket;

@interface MVIRCChatConnection : MVChatConnection {
@private
	AsyncSocket *_chatConnection;
	NSThread *_connectionThread;
	NSMutableDictionary *_knownUsers;
	NSString *_server;
	NSString *_currentNickname;
	NSString *_nickname;
	NSString *_username;
	NSString *_password;
	NSString *_realName;
	NSString *_proxyServer;
	NSString *_proxyUsername;
	NSString *_proxyPassword;
	unsigned short _serverPort;
	unsigned short _proxyServerPort;
	BOOL _secure;
}
+ (NSArray *) defaultServerPorts;
@end

#pragma mark -

@interface MVChatConnection (MVIRCChatConnectionPrivate)
- (void) _readNextMessageFromServer;

- (void) _handleCTCP:(NSMutableData *) data asRequest:(BOOL) request fromSender:(MVChatUser *) sender forRoom:(MVChatRoom *) room;
	
+ (NSData *) _flattenedIRCDataForMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) enc andChatFormat:(MVChatMessageFormat) format;
- (void) _sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding toTarget:(NSString *) target asAction:(BOOL) action;

- (void) _processErrorCode:(int) errorCode withContext:(char *) context;

- (void) _updateKnownUser:(MVChatUser *) user withNewNickname:(NSString *) nickname;
@end
