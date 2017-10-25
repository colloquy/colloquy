#import "MVFileTransfer.h"
#import "MVFileTransferPrivate.h"
#include <libsilc/silcincludes.h>
#include <libsilcclient/silcclient.h>

NS_ASSUME_NONNULL_BEGIN

@interface MVSILCUploadFileTransfer : MVUploadFileTransfer {
	SilcUInt32 _sessionID;
}
- (instancetype) initWithSessionID:(SilcUInt32) sessionID toUser:(MVChatUser *) user;
@end

#pragma mark -

@interface MVSILCDownloadFileTransfer : MVDownloadFileTransfer {
	SilcUInt32 _sessionID;
}
- (instancetype) initWithSessionID:(SilcUInt32) sessionID toUser:(MVChatUser *) user;
@end

#pragma mark -

@interface MVSILCUploadFileTransfer (MVSILCUploadFileTransferPrivate)
@property (getter=_sessionID, setter=_setSessionID:) SilcUInt32 sessionID;
- (SilcUInt32) _sessionID;
- (void) _setSessionID:(SilcUInt32) sessionID;
@end

#pragma mark -

@interface MVSILCDownloadFileTransfer (MVSILCDownloadFileTransferPrivate)
@property (getter=_sessionID, setter=_setSessionID:) SilcUInt32 sessionID;
- (SilcUInt32) _sessionID;
- (void) _setSessionID:(SilcUInt32) sessionID;
@end

NS_ASSUME_NONNULL_END
