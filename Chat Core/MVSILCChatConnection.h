#include <libsilc/silcincludes.h>
#include <libsilcclient/silcclient.h>
#import "MVChatConnection.h"

#define SilcLock(client) silc_mutex_lock(silc_schedule_get_callback_lock((client)->schedule))
#define SilcUnlock(client) silc_mutex_unlock(silc_schedule_get_callback_lock((client)->schedule))

@interface MVSILCChatConnection : MVChatConnection {
@private
	SilcClient _silcClient;
    SilcClientParams _silcClientParams;

	SilcClientConnection _silcConn;

	NSString *_silcServer;
	unsigned short _silcPort;

	NSString *_silcPassword;

	NSString *_certificatePassword;
	BOOL _waitForCertificatePassword;

	NSMutableDictionary *_knownUsers;
	NSMutableDictionary *_sentCommands;
	NSMutableArray *_queuedCommands;

	BOOL _sentQuitCommand;
	BOOL _lookingUpUsers;
}
+ (NSArray *) defaultServerPorts;
@end

#pragma mark -

@interface MVChatConnection (MVSILCChatConnectionPrivate)
+ (const char *) _flattenedSILCStringForMessage:(NSAttributedString *) message andChatFormat:(MVChatMessageFormat) format;

- (void) _initLocalUser;

- (SilcClient) _silcClient;
- (SilcClientParams *) _silcClientParams;

- (SilcClientConnection) _silcConn;
- (void) _setSilcConn:(SilcClientConnection) aSilcConn;

- (BOOL) _loadKeyPair;
- (BOOL) _isKeyPairLoaded;
- (void) _connectKeyPairLoaded:(NSNotification *) notification;

- (NSMutableArray *) _queuedCommands;
- (NSMutableDictionary *) _sentCommands;

- (NSData *) _detachInfo;
- (void) _setDetachInfo:(NSData *) info;

- (void) _addCommand:(NSString *) raw forNumber:(SilcUInt16) cmd_ident;
- (NSString *) _getCommandForNumber:(SilcUInt16) cmd_ident;

- (void) _sendCommandSucceededNotify:(NSString *) message;
- (void) _sendCommandFailedNotify:(NSString *) message;

- (MVChatUser *) _chatUserWithClientEntry:(SilcClientEntry) clientEntry;
- (void) _updateKnownUser:(MVChatUser *) user withClientEntry:(SilcClientEntry) clientEntry;

- (NSString *) _publicKeyFilename:(SilcSocketType) connType andPublicKey:(unsigned char *) pk withLen:(SilcUInt32) pkLen usingSilcConn:(SilcClientConnection) conn;
@end

#pragma mark -

@interface MVChatConnection (MVSILCChatConnectionPrivateSuper)
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