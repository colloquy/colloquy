#import "MVFileTransfer.h"
#import "MVFileTransferPrivate.h"
#import "Transmission.h"

@class AsyncSocket;
@class MVDirectClientConnection;

@interface MVIRCUploadFileTransfer : MVUploadFileTransfer {
@private
	MVDirectClientConnection *_directClientConnection;
	NSFileHandle *_fileHandle;
	BOOL _fileNameQuoted;
	BOOL _readData;
	BOOL _doneSending;
	BOOL _releasing;
	long long _passiveId;
}
- (void) _setupAndStart;
- (void) _sendNextPacket;

- (void) _setPassiveIdentifier:(long long) identifier;
- (long long) _passiveIdentifier;

- (void) _setFileNameQuoted:(BOOL) quoted;
- (BOOL) _fileNameQuoted;
@end

#pragma mark -

@interface MVIRCDownloadFileTransfer : MVDownloadFileTransfer {
	MVDirectClientConnection *_directClientConnection;
	NSFileHandle *_fileHandle;
	BOOL _fileNameQuoted;
	BOOL _turbo;
	BOOL _releasing;
	long long _passiveId;
}
- (void) _setupAndStart;

- (void) _setTurbo:(BOOL) turbo;
- (BOOL) _turbo;

- (void) _setPassiveIdentifier:(long long) identifier;
- (long long) _passiveIdentifier;

- (void) _setFileNameQuoted:(BOOL) quoted;
- (BOOL) _fileNameQuoted;
@end
