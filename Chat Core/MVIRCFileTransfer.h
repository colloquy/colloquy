#import "MVFileTransfer.h"
#import "MVFileTransferPrivate.h"


NS_ASSUME_NONNULL_BEGIN

@interface MVIRCUploadFileTransfer : MVUploadFileTransfer
- (void) _setupAndStart;
- (void) _sendNextPacket;

@property (setter=_setPassiveIdentifier:) long long _passiveIdentifier;
@property (setter=_setFileNameQuoted:) BOOL _fileNameQuoted;
@end

#pragma mark -

@interface MVIRCDownloadFileTransfer : MVDownloadFileTransfer
- (void) _setupAndStart;

@property (setter=_setTurbo:) BOOL _turbo;
@property (setter=_setPassiveIdentifier:) long long _passiveIdentifier;
@property (setter=_setFileNameQuoted:) BOOL _fileNameQuoted;
@end

NS_ASSUME_NONNULL_END
