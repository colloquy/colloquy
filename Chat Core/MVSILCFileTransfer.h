#import "MVFileTransfer.h"
#import "MVFileTransferPrivate.h"
#include <libsilc/silcincludes.h>
#include <libsilcclient/silcclient.h>

NS_ASSUME_NONNULL_BEGIN

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

@interface MVSILCUploadFileTransfer (MVSILCUploadFileTransferPrivate)
- (SilcUInt32) _sessionID;
- (void) _setSessionID:(SilcUInt32) sessionID;
@end

#pragma mark -

@interface MVSILCDownloadFileTransfer (MVSILCDownloadFileTransferPrivate)
- (SilcUInt32) _sessionID;
- (void) _setSessionID:(SilcUInt32) sessionID;
@end

NS_ASSUME_NONNULL_END
