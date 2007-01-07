#import "MVDirectChatConnection.h"

@interface MVDirectChatConnection (MVDirectChatConnectionPrivate)
- (void) _writeMessage:(NSData *) message;
- (void) _readNextMessage;
- (void) _setStatus:(MVDirectChatConnectionStatus) status;
- (void) _setStartDate:(NSDate *) startDate;
- (void) _setHost:(NSHost *) host;
- (void) _setPort:(unsigned short) port;
- (void) _setPassive:(BOOL) passive;
- (void) _postError:(NSError *) error;
@end
