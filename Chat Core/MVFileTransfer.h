@class MVChatConnection;
@class MVChatUser;

extern NSString *MVDownloadFileTransferOfferNotification;
extern NSString *MVFileTransferStartedNotification;
extern NSString *MVFileTransferFinishedNotification;
extern NSString *MVFileTransferErrorOccurredNotification;

extern NSString *MVFileTransferErrorDomain;

typedef enum {
	MVFileTransferDoneStatus = 'trDn',
	MVFileTransferNormalStatus = 'trNo',
	MVFileTransferHoldingStatus = 'trHo',
	MVFileTransferStoppedStatus = 'trSt',
	MVFileTransferErrorStatus = 'trEr'
} MVFileTransferStatus;

typedef enum {
	MVFileTransferConnectionError = -1,
	MVFileTransferFileCreationError = -2,
	MVFileTransferFileOpenError = -3,
	MVFileTransferAlreadyExistsError = -4,
	MVFileTransferUnexpectedlyEndedError = -5,
	MVFileTransferKeyAgreementError = -6
} MVFileTransferError;

@interface MVFileTransfer : NSObject {
@protected
	unsigned long long _finalSize;
	unsigned long long _transfered;
	NSDate *_startDate;
	NSHost *_host;
	BOOL _passive : 1;
	unsigned short _port;
	unsigned long long _startOffset;
	MVChatUser *_user;
	MVFileTransferStatus _status;
	NSError *_lastError;
	unsigned int _hash;
}
+ (void) setFileTransferPortRange:(NSRange) range;
+ (NSRange) fileTransferPortRange;

#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
@property(readonly) BOOL upload;
@property(readonly) BOOL download;
@property(readonly) BOOL passive;
@property(readonly, ivar) MVFileTransferStatus status;
@property(readonly, ivar) NSError *lastError;

@property(readonly, ivar) unsigned long long finalSize;
@property(readonly, ivar) unsigned long long transfered;

@property(readonly, ivar) NSDate *startDate;
@property(readonly, ivar) unsigned long long startOffset;

@property(readonly, ivar) NSHost *host;
@property(readonly, ivar) unsigned short port;

@property(readonly, ivar) MVChatUser *user;

#else

- (MVFileTransferStatus) status;
- (NSError *) lastError;

- (unsigned long long) finalSize;
- (unsigned long long) transfered;

- (NSDate *) startDate;
- (unsigned long long) startOffset;

- (NSHost *) host;
- (unsigned short) port;

- (MVChatUser *) user;
#endif

- (id) initWithUser:(MVChatUser *) user;

- (BOOL) isUpload;
- (BOOL) isDownload;
- (BOOL) isPassive;

- (void) cancel;
@end

#pragma mark -

@interface MVUploadFileTransfer : MVFileTransfer {
@protected
	NSString *_source;
}
+ (id) transferWithSourceFile:(NSString *) path toUser:(MVChatUser *) user passively:(BOOL) passive;

#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
@property(readonly, ivar) NSString *source;
#else
- (NSString *) source;
#endif
@end

#pragma mark -

@interface MVDownloadFileTransfer : MVFileTransfer {
@protected
	BOOL _rename;
	NSString *_destination;
	NSString *_originalFileName;
}
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
@property(ivar, bycopy) NSString *destination;
@property(readonly, ivar) NSString *originalFileName;
#else
- (NSString *) destination;
- (void) setDestination:(NSString *) path;
- (NSString *) originalFileName;
#endif

- (void) setDestination:(NSString *) path renameIfFileExists:(BOOL) allow;

- (void) reject;

- (void) accept;
- (void) acceptByResumingIfPossible:(BOOL) resume;
@end
