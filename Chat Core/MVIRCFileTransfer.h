#import "MVFileTransfer.h"
#import "MVFileTransferPrivate.h"
#import "Transmission.h"

NS_ASSUME_NONNULL_BEGIN

@interface MVIRCUploadFileTransfer : MVUploadFileTransfer
- (void) _setupAndStart;
- (void) _sendNextPacket;

- (void) _setPassiveIdentifier:(long long) identifier;
@property (readonly) long long _passiveIdentifier;

- (void) _setFileNameQuoted:(BOOL) quoted;
@property (readonly) BOOL _fileNameQuoted;
@end

#pragma mark -

@interface MVIRCDownloadFileTransfer : MVDownloadFileTransfer
- (void) _setupAndStart;

- (void) _setTurbo:(BOOL) turbo;
@property (readonly) BOOL _turbo;

- (void) _setPassiveIdentifier:(long long) identifier;
@property (readonly) long long _passiveIdentifier;

- (void) _setFileNameQuoted:(BOOL) quoted;
@property (readonly) BOOL _fileNameQuoted;
@end

NS_ASSUME_NONNULL_END
