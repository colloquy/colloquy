#import "MVChatConnection.h"
#import "common.h"

extern NSRecursiveLock *MVIRCChatConnectionThreadLock;

@interface MVIRCChatConnection : MVChatConnection {
@private
	NSMutableDictionary *_knownUsers;
	NSString *_proxyUsername;
	NSString *_proxyPassword;
	SERVER_REC *_chatConnection;
	SERVER_CONNECT_REC *_chatConnectionSettings;
	NSConnection *_irssiThreadConnection;
	MVIRCChatConnection *_irssiThreadProxy;
}
+ (NSArray *) defaultServerPorts;
@end

#pragma mark -

@interface MVIRCConnectionThreadHelper : NSObject {}
- (NSConnection *) vendChatConnection:(MVIRCChatConnection *) connection;
@end

#pragma mark -

@protocol MVIRCChatConnectionIrssiThread
- (oneway void) _sendRawMessage:(NSString *) raw immediately:(BOOL) now;
- (oneway void) _sendMessage:(const char *) msg toTarget:(NSString *) target asAction:(BOOL) action;
@end

#pragma mark -

@interface MVChatConnection (MVIRCChatConnectionPrivate) <MVIRCChatConnectionIrssiThread>
+ (MVIRCChatConnection *) _connectionForServer:(SERVER_REC *) server;

+ (void) _registerCallbacks;
+ (void) _deregisterCallbacks;

+ (const char *) _flattenedIRCStringForMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) enc andChatFormat:(MVChatMessageFormat) format;

- (MVIRCChatConnection *) _irssiThreadProxy;

- (SERVER_REC *) _irssiConnection;
- (void) _setIrssiConnection:(SERVER_REC *) server;

- (SERVER_CONNECT_REC *) _irssiConnectSettings;
- (void) _setIrssiConnectSettings:(SERVER_CONNECT_REC *) settings;

- (void) _forceDisconnect;

- (void) _updateKnownUser:(MVChatUser *) user withNewNickname:(NSString *) nickname;

- (oneway void) _sendRawMessage:(NSString *) raw immediately:(BOOL) now;
@end

#pragma mark -

@interface MVChatConnection (MVIRCChatConnectionPrivateSuper)
- (void) _willConnect;
- (void) _didConnect;
- (void) _didNotConnect;
- (void) _willDisconnect;
- (void) _didDisconnect;

- (void) _addJoinedRoom:(MVChatRoom *) room;
- (void) _removeJoinedRoom:(MVChatRoom *) room;
@end