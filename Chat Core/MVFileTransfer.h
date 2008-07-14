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
	NSString *_host;
	BOOL _passive;
	unsigned short _port;
	unsigned long long _startOffset;
	MVChatUser *_user;
	MVFileTransferStatus _status;
	NSError *_lastError;
	unsigned int _hash;
}
+ (void) setFileTransferPortRange:(NSRange) range;
+ (NSRange) fileTransferPortRange;

+ (void) setAutoPortMappingEnabled:(BOOL) enable;
+ (BOOL) isAutoPortMappingEnabled;

#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
@property(readonly, getter=isUpload) BOOL upload;
@property(readonly, getter=isDownload) BOOL download;
@property(readonly, getter=isPassive) BOOL passive;
@property(readonly) MVFileTransferStatus status;
@property(readonly) NSError *lastError;

@property(readonly) unsigned long long finalSize;
@property(readonly) unsigned long long transfered;

@property(readonly) NSDate *startDate;
@property(readonly) unsigned long long startOffset;

@property(readonly) NSString *host;
@property(readonly) unsigned short port;

@property(readonly) MVChatUser *user;

#else

- (MVFileTransferStatus) status;
- (NSError *) lastError;

- (unsigned long long) finalSize;
- (unsigned long long) transfered;

- (NSDate *) startDate;
- (unsigned long long) startOffset;

- (NSString *) host;
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
@property(readonly) NSString *source;
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
@property(copy) NSString *destination;
@property(readonly) NSString *originalFileName;
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
