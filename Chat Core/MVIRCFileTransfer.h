#import "MVFileTransfer.h"
#import "MVFileTransferPrivate.h"
#import "Transmission.h"

@class MVDirectClientConnection;

@interface MVIRCUploadFileTransfer : MVUploadFileTransfer {
@private
	MVDirectClientConnection *_directClientConnection;
	NSFileHandle *_fileHandle;
	BOOL _fileNameQuoted;
	BOOL _readData;
	BOOL _doneSending;
	long long _passiveId;
}
- (void) _setupAndStart;
- (void) _sendNextPacket;

@property (setter=_setPassiveIdentifier:) long long _passiveIdentifier;
@property (setter=_setFileNameQuoted:) BOOL _fileNameQuoted;
@end

#pragma mark -

@interface MVIRCDownloadFileTransfer : MVDownloadFileTransfer {
	MVDirectClientConnection *_directClientConnection;
	NSFileHandle *_fileHandle;
	BOOL _fileNameQuoted;
	BOOL _turbo;
	long long _passiveId;
}
- (void) _setupAndStart;

@property (setter=_setTurbo:) BOOL _turbo;
@property (setter=_setPassiveIdentifier:) long long _passiveIdentifier;
@property (setter=_setFileNameQuoted:) BOOL _fileNameQuoted;
@end
