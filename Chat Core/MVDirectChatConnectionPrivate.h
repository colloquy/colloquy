#import "MVDirectChatConnection.h"

@interface MVDirectChatConnection (MVDirectChatConnectionPrivate)
- (id) initWithUser:(MVChatUser *) user;

- (void) _writeMessage:(NSData *) message;
- (void) _readNextMessage;

- (void) _setStatus:(MVDirectChatConnectionStatus) status;
- (void) _setHost:(NSString *) host;
- (void) _setPort:(unsigned short) port;
- (void) _setPassive:(BOOL) passive;
- (void) _setLocalRequest:(BOOL) localRequest;
- (void) _setPassiveIdentifier:(long long) identifier;
- (long long) _passiveIdentifier;
- (void) _postError:(NSError *) error;
@end
