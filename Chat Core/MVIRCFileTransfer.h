#import "MVFileTransfer.h"
#import "MVFileTransferPrivate.h"

@class AsyncSocket;
@class NSThread;

@interface MVIRCUploadFileTransfer : MVUploadFileTransfer {
	AsyncSocket *_connection;
	NSThread *_connectionThread;
}
@end

#pragma mark -

@interface MVIRCDownloadFileTransfer : MVDownloadFileTransfer {
	AsyncSocket *_connection;
	NSThread *_connectionThread;
	NSFileHandle *_fileHandle;
	BOOL _fileNameQuoted;
	unsigned int _passiveId;
}
- (void) _setupAndStart;
@end
