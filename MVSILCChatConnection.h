#include <libsilc/silcincludes.h>
#include <libsilcclient/silcclient.h>
#import "MVChatConnection.h"

@interface MVSILCChatConnection : MVChatConnection {
@private
	SilcClient _silcClient;
    SilcClientParams _silcClientParams;
	NSRecursiveLock *_silcClientLock;

	NSMutableArray *_joinedChannels;
	NSMutableArray *_queuedCommands;
	NSLock *_queuedCommandsLock;

	SilcClientConnection _silcConn;

	NSString *_silcServer;
	unsigned short _silcPort;

	NSString *_silcPassword;
	
	NSString *_certificatePassword;
	BOOL _waitForCertificatePassword;
	
	NSMutableDictionary *_sentCommands;
	NSLock *_sentCommandsLock;
	
	BOOL _sentQuitCommand;
}
@end

#pragma mark -

@interface MVSILCChatConnection (MVSILCChatConnectionPrivate)
+ (const char *) _flattenedSILCStringForMessage:(NSAttributedString *) message;

- (SilcClient) _silcClient;
- (SilcClientParams *) _silcClientParams;
- (NSRecursiveLock *) _silcClientLock;

- (SilcClientConnection) _silcConn;
- (void) _setSilcConn:(SilcClientConnection) aSilcConn;

- (NSMutableArray *) _joinedChannels;
- (void) _addChannel:(NSString *)channel_name;
- (void) _addUser:(NSString *)nick_name toChannel:(NSString *)channel_name withMode:(NSNumber *)mode;
- (void) _delUser:(NSString *)nick_name fromChannel:(NSString *)channel_name;
- (void) _delUser:(NSString *)nick_name;
- (void) _delChannel:(NSString *)channel_name;
- (void) _userChangedNick:(NSString *)old_nick_name to:(NSString *)new_nick_name;
- (void) _userModeChanged:(NSString *)nick_name onChannel:(NSString *)channel_name toMode:(NSNumber *)mode;
- (NSArray *) _getChannelsForUser:(NSString *)nick_name;
- (NSMutableDictionary *) _getChannel:(NSString *)channel_name;
- (NSNumber *) _getModeForUser:(NSString *)nick_name onChannel:(NSString *)channel_name;

- (NSMutableArray *) _queuedCommands;
- (NSLock *) _queuedCommandsLock;

- (BOOL) _loadKeyPair;
- (BOOL) _isKeyPairLoaded;
- (void) _connectKeyPairLoaded:(NSNotification *) notification;

- (void) _addCommand:(NSString *)raw forNumber:(SilcUInt16) cmd_ident;
- (NSString *) _getCommandForNumber:(SilcUInt16) cmd_ident;
- (NSLock *) _sentCommandsLock;
- (NSMutableDictionary *) _sentCommands;

- (void) _sendCommandSucceededNotify:(NSString *) message;
- (void) _sendCommandFailedNotify:(NSString *) message;
@end

#pragma mark -

@interface MVChatConnection (MVChatConnectionPrivate)
- (void) _willConnect;
- (void) _didConnect;
- (void) _didNotConnect;
- (void) _willDisconnect;
- (void) _didDisconnect;

- (void) _addJoinedRoom:(MVChatRoom *) room;
- (void) _removeJoinedRoom:(MVChatRoom *) room;
@end