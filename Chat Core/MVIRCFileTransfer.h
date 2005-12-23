#import "MVFileTransfer.h"
#import "common.h"
#import "core.h"
#import "servers.h"
#import "irc.h"
#import "dcc-file.h"
#import "dcc-send.h"
#import "dcc-get.h"

@interface MVIRCUploadFileTransfer : MVUploadFileTransfer {
	void *_dcc;
	int _transferQueue;
}
- (id) initWithDCCFileRecord:(void *) record toUser:(MVChatUser *) user;
@end

#pragma mark -

@interface MVIRCDownloadFileTransfer : MVDownloadFileTransfer {
	void *_dcc;
}
- (id) initWithDCCFileRecord:(void *) record fromUser:(MVChatUser *) user;
@end

#pragma mark -

@interface MVFileTransfer (MVFileTransferPrivate)
- (void) _setStatus:(MVFileTransferStatus) status;
- (void) _postError:(NSError *) error;
@end

#pragma mark -

@interface MVFileTransfer (MVIRCFileTransferPrivate)
+ (id) _transferForDCCFileRecord:(FILE_DCC_REC *) record;
@end

#pragma mark -

@interface MVIRCUploadFileTransfer (MVIRCUploadFileTransferPrivate)
- (SEND_DCC_REC *) _DCCFileRecord;
- (void) _setDCCFileRecord:(FILE_DCC_REC *) record;
- (void) _destroying;
@end

#pragma mark -

@interface MVIRCDownloadFileTransfer (MVIRCDownloadFileTransferPrivate)
- (GET_DCC_REC *) _DCCFileRecord;
- (void) _setDCCFileRecord:(FILE_DCC_REC *) record;
- (void) _destroying;
@end