#import "MVFileTransfer.h"
#import "MVFileTransferPrivate.h"

@class AsyncSocket;
@class NSThread;

@interface MVIRCUploadFileTransfer : MVUploadFileTransfer {
	AsyncSocket *_connection;
	AsyncSocket *_clientConnection;
	NSThread *_connectionThread;
	NSFileHandle *_fileHandle;
	BOOL _fileNameQuoted;
	BOOL _done;
	unsigned int _passiveId;
}
- (void) _setupAndStart;
- (void) _sendNextPacket;
- (void) _finish;
@end

#pragma mark -

@interface MVIRCDownloadFileTransfer : MVDownloadFileTransfer {
	AsyncSocket *_connection;
	NSThread *_connectionThread;
	NSFileHandle *_fileHandle;
	BOOL _fileNameQuoted;
	BOOL _done;
	unsigned int _passiveId;
}
- (void) _setupAndStart;
- (void) _finish;
@end
