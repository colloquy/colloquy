#import "MVDirectChatConnection.h"

NS_ASSUME_NONNULL_BEGIN

@interface MVDirectChatConnection (MVDirectChatConnectionPrivate)
- (instancetype) initWithUser:(MVChatUser *) user;

- (void) _writeMessage:(NSData *) message;
- (void) _readNextMessage;

- (void) _setStatus:(MVDirectChatConnectionStatus) status;
- (void) _setHost:(NSString *) host;
- (void) _setPort:(unsigned short) port;
- (void) _setPassive:(BOOL) passive;
- (void) _setLocalRequest:(BOOL) localRequest;
- (void) _setPassiveIdentifier:(long long) identifier;
- (void) _postError:(NSError *) error;

@property (readonly) long long _passiveIdentifier;
@end

NS_ASSUME_NONNULL_END
