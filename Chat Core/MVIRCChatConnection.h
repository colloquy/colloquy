#import "MVChatConnection.h"

@class AsyncSocket;

@interface MVIRCChatConnection : MVChatConnection {
@private
	AsyncSocket *_chatConnection;
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
- (void) _handleCommand:(id) command parameters:(NSArray *) parameters fromSender:(NSString *) sender username:(NSString *) user host:(NSString *) host;

+ (NSData *) _flattenedIRCDataForMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) enc andChatFormat:(MVChatMessageFormat) format;
- (void) _sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding toTarget:(NSString *) target asAction:(BOOL) action;

- (void) _processErrorCode:(int) errorCode withContext:(char *) context;

- (void) _updateKnownUser:(MVChatUser *) user withNewNickname:(NSString *) nickname;
@end

#pragma mark -

@interface MVChatConnection (MVIRCChatConnectionPrivateSuper)
- (void) _willConnect;
- (void) _didConnect;
- (void) _didNotConnect;
- (void) _willDisconnect;
- (void) _didDisconnect;
- (void) _postError:(NSError *) error;
- (void) _setStatus:(MVChatConnectionStatus) status;

- (void) _addJoinedRoom:(MVChatRoom *) room;
- (void) _removeJoinedRoom:(MVChatRoom *) room;
@end