#import "MVFileTransfer.h"

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