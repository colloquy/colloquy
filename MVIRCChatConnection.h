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
}
+ (NSArray *) defaultServerPorts;
@end

#pragma mark -

@interface MVChatConnection (MVIRCChatConnectionPrivate)
+ (MVIRCChatConnection *) _connectionForServer:(SERVER_REC *) server;

+ (void) _registerCallbacks;
+ (void) _deregisterCallbacks;

+ (const char *) _flattenedIRCStringForMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) enc;

- (SERVER_REC *) _irssiConnection;
- (void) _setIrssiConnection:(SERVER_REC *) server;

- (SERVER_CONNECT_REC *) _irssiConnectSettings;
- (void) _setIrssiConnectSettings:(SERVER_CONNECT_REC *) settings;

- (void) _forceDisconnect;

- (void) _updateKnownUser:(MVChatUser *) user withNewNickname:(NSString *) nickname;
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