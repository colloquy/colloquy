#import <Foundation/NSObject.h>
#import <Foundation/NSRange.h>

@class MVChatConnection;
@class NSString;
@class NSDate;
@class NSHost;

extern NSString *MVDownloadFileTransferOfferNotification;
extern NSString *MVFileTransferStartedNotification;
extern NSString *MVFileTransferFinishedNotification;

typedef enum {
	MVFileTransferDoneStatus = 'trDn',
	MVFileTransferNormalStatus = 'trNo',
	MVFileTransferHoldingStatus = 'trHo',
	MVFileTransferStoppedStatus = 'trSt',
	MVFileTransferErrorStatus = 'trEr'
} MVFileTransferStatus;

@interface MVFileTransfer : NSObject {
	void *_dcc; /* FILE_DCC_REC */
	unsigned long long _finalSize;
	unsigned long long _transfered;
	NSDate *_startDate;
	NSHost *_host;
	unsigned short _port;
	unsigned long long _startOffset;
	MVChatConnection *_connection;
	NSString *_user;
	MVFileTransferStatus _status;
}
+ (void) setFileTransferPortRange:(NSRange) range;
+ (NSRange) fileTransferPortRange;

- (id) initWithDCCFileRecord:(void *) record fromConnection:(MVChatConnection *) connection;

- (BOOL) isUpload;
- (BOOL) isDownload;
- (MVFileTransferStatus) status;
- (NSError *) lastError;

- (unsigned long long) finalSize;
- (unsigned long long) transfered;

- (NSDate *) startDate;
- (unsigned long long) startOffset;

- (NSHost *) host;
- (unsigned short) port;

- (MVChatConnection *) connection;
- (NSString *) user;

- (void) cancel;
@end

#pragma mark -

@interface MVUploadFileTransfer : MVFileTransfer {
	int _transferQueue;
	NSString *_source;
}
+ (id) transferWithSourceFile:(NSString *) path toUser:(NSString *) nickname onConnection:(MVChatConnection *) connection;

- (NSString *) source;
@end

#pragma mark -

@interface MVDownloadFileTransfer : MVFileTransfer {
	NSString *_destination;
	NSString *_originalFileName;
}
- (void) setDestination:(NSString *) path renameIfFileExists:(BOOL) allow;
- (NSString *) destination;

- (NSString *) originalFileName;

- (void) reject;

- (void) accept;
- (void) acceptByResumingIfPossible:(BOOL) resume;
@end