#import <Foundation/NSObject.h>
#import <Foundation/NSRange.h>

extern NSString *MVFileTransferOfferNotification;

@interface MVFileTransfer : NSObject {
	void *_dcc; /* FILE_DCC_REC */
}
+ (void) setFileTransferPortRange:(NSRange) range;
+ (NSRange) fileTransferPortRange;

- (id) initWithDCCFileRecord:(void *) record;

- (BOOL) isUpload;
- (BOOL) isDownload;

- (unsigned long) finalSize;
- (unsigned long) transfered;

- (NSDate *) startDate;
- (unsigned long) startOffset;

- (NSHost *) host;
- (unsigned short) port;

- (void) cancel;
@end

@interface MVUploadFileTransfer : MVFileTransfer {}

@end

@interface MVDownloadFileTransfer : MVFileTransfer {
	NSString *_destination;
}
- (void) setDestination:(NSString *) path allowOverwriteOrResume:(BOOL) allow;
- (void) accept;
- (void) acceptByResumingIfPossible:(BOOL) resume;
@end