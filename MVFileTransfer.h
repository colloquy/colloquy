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

- (void) cancel;
@end

@interface MVUploadFileTransfer : MVFileTransfer {}

@end

@interface MVDownloadFileTransfer : MVFileTransfer {
	NSString *_destination;
	NSString *_fromNickname;
	NSString *_originalFileName;
}
- (void) setDestination:(NSString *) path renameIfFileExists:(BOOL) allow;
- (NSString *) destination;

- (NSString *) fromNickname;
- (NSString *) originalFileName;

- (void) reject;

- (void) accept;
- (void) acceptByResumingIfPossible:(BOOL) resume;
@end