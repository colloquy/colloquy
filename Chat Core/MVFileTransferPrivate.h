#import "MVFileTransfer.h"

@interface MVFileTransfer (MVFileTransferPrivate)
- (void) _setStatus:(MVFileTransferStatus) status;
- (void) _postError:(NSError *) error;
@end
