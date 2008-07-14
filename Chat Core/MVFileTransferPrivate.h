#import "MVFileTransfer.h"

@interface MVFileTransfer (MVFileTransferPrivate)
- (void) _setStatus:(MVFileTransferStatus) status;
- (void) _setFinalSize:(unsigned long long) finalSize;
- (void) _setTransfered:(unsigned long long) transfered;
- (void) _setStartOffset:(unsigned long long) startOffset;
- (void) _setStartDate:(NSDate *) startDate;
- (void) _setHost:(NSString *) host;
- (void) _setPort:(unsigned short) port;
- (void) _setPassive:(BOOL) passive;
- (void) _postError:(NSError *) error;
@end

@interface MVUploadFileTransfer (MVUploadFileTransferPrivate)
- (void) _setSource:(NSString *) source;
@end

@interface MVDownloadFileTransfer (MVDownloadFileTransferPrivate)
- (void) _setOriginalFileName:(NSString *) originalFileName;
@end
