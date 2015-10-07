#import "MVChatConnection.h"
#import "MVChatConnectionPrivate.h"
#include <libsilc/silcincludes.h>
#include <libsilcclient/silcclient.h>

#define SilcLock(client) silc_mutex_lock(silc_schedule_get_callback_lock((client)->schedule))
#define SilcUnlock(client) silc_mutex_unlock(silc_schedule_get_callback_lock((client)->schedule))

NS_ASSUME_NONNULL_BEGIN

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

	NSMutableDictionary *_sentCommands;
	NSMutableArray *_queuedCommands;

	BOOL _sentQuitCommand;
	BOOL _lookingUpUsers;
}
+ (NSArray *) defaultServerPorts;

- (MVChatRoom *) joinedChatRoomWithChannel:(SilcChannelEntry) channel;
@end

#pragma mark -

@interface MVChatConnection (MVSILCChatConnectionPrivate)
+ (const char *) _flattenedSILCStringForMessage:(MVChatString *) message andChatFormat:(MVChatMessageFormat) format;

- (void) _initLocalUser;

- (SilcClient) _silcClient;
- (SilcClientParams *) _silcClientParams;

- (SilcClientConnection) _silcConn;
- (void) _setSilcConn:(SilcClientConnection __nullable) aSilcConn;

- (void) _stopSilcRunloop;

- (BOOL) _loadKeyPair;
- (BOOL) _isKeyPairLoaded;
- (void) _connectKeyPairLoaded:(NSNotification *) notification;

- (NSMutableArray *) _queuedCommands;
- (NSMutableDictionary *) _sentCommands;

- (NSData *) _detachInfo;
- (void) _setDetachInfo:(NSData * __nullable) info;

- (void) _addCommand:(NSString *) raw forNumber:(SilcUInt16) cmd_ident;
- (NSString *) _getCommandForNumber:(SilcUInt16) cmd_ident;

- (void) _sendCommandSucceededNotify:(NSString *) message;
- (void) _sendCommandFailedNotify:(NSString *) message;

- (MVChatUser *) _chatUserWithClientEntry:(SilcClientEntry) clientEntry;
- (void) _updateKnownUser:(MVChatUser *) user withClientEntry:(SilcClientEntry) clientEntry;

- (NSString *) _publicKeyFilename:(SilcSocketType) connType andPublicKey:(unsigned char *) pk withLen:(SilcUInt32) pkLen usingSilcConn:(SilcClientConnection) conn;
@end

NS_ASSUME_NONNULL_END
