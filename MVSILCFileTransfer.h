#include <libsilc/silcincludes.h>
#include <libsilcclient/silcclient.h>
#import "MVFileTransfer.h"

@interface MVSILCUploadFileTransfer : MVUploadFileTransfer {
	SilcUInt32 _sessionID;
}
- (id) initWithSessionID:(SilcUInt32) sessionID toUser:(MVChatUser *) user;
@end

#pragma mark -

@interface MVSILCDownloadFileTransfer : MVDownloadFileTransfer {
	SilcUInt32 _sessionID;
}
- (id) initWithSessionID:(SilcUInt32) sessionID toUser:(MVChatUser *) user;
@end

#pragma mark -

@interface MVFileTransfer (MVFileTransferPrivate)
- (void) _setStatus:(MVFileTransferStatus) status;
- (void) _postError:(NSError *) error;
@end

#pragma mark -

@interface MVSILCUploadFileTransfer (MVSILCUploadFileTransferPrivate)
- (SilcUInt32) _sessionID;
- (void) _setSessionID:(SilcUInt32) sessionID;
@end

#pragma mark -

@interface MVSILCDownloadFileTransfer (MVSILCDownloadFileTransferPrivate)
- (SilcUInt32) _sessionID;
- (void) _setSessionID:(SilcUInt32) sessionID;
@end