#import "MVFileTransfer.h"
#import "MVFileTransferPrivate.h"

@class AsyncSocket;

@interface MVIRCUploadFileTransfer : MVUploadFileTransfer {
	AsyncSocket *_connection;
	AsyncSocket *_acceptConnection;
	NSThread *_connectionThread;
	NSFileHandle *_fileHandle;
	NSConditionLock *_threadWaitLock;
	BOOL _fileNameQuoted;
	BOOL _readData;
	BOOL _doneSending;
	BOOL _done;
	BOOL _releasing;
	unsigned int _passiveId;
}
- (void) _setupAndStart;
- (void) _sendNextPacket;
- (void) _finish;
- (unsigned int) _passiveIdentifier;
@end

#pragma mark -

@interface MVIRCDownloadFileTransfer : MVDownloadFileTransfer {
	AsyncSocket *_connection;
	AsyncSocket *_acceptConnection;
	NSThread *_connectionThread;
	NSFileHandle *_fileHandle;
	NSConditionLock *_threadWaitLock;
	BOOL _fileNameQuoted;
	BOOL _done;
	BOOL _turbo;
	BOOL _releasing;
	unsigned int _passiveId;
}
- (void) _setupAndStart;
- (void) _finish;
- (void) _setTurbo:(BOOL) turbo;
- (void) _setPassiveIdentifier:(unsigned int) identifier;
- (unsigned int) _passiveIdentifier;
- (void) _setFileNameQuoted:(unsigned int) quoted;
@end
