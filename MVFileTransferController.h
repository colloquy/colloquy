#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>

typedef enum {
	MVUploadTransfer = 0x1,
	MVDownloadTransfer = 0x2
} MVTransferOperation;

typedef enum {
	MVTransferDone = 0x0,
	MVTransferNormal = 0x1,
	MVTransferHolding = 0x2,
	MVTransferStopped = 0x3,
	MVTransferError = 0x4
} MVTransferStatus;

NSString *MVPrettyFileSize( unsigned long size );
NSString *MVReadableTime( NSTimeInterval date, BOOL longFormat );

@class NSPanel;
@class NSProgressIndicator;
@class NSTextField;
@class NSTableView;
@class NSMutableArray;
@class NSRecursiveLock;
@class MVChatConnection;

@interface MVFileTransferController : NSWindowController {
@private
	IBOutlet NSProgressIndicator *progressBar;
	IBOutlet NSTextField *transferStatus;
	IBOutlet NSTableView *currentFiles;
	NSMutableArray *_transferStorage, *_calculationItems;
}
+ (MVFileTransferController *) defaultManager;
- (IBAction) showTransferManager:(id) sender;

- (void) downloadFileAtURL:(NSURL *) url toLocalFile:(NSString *) path;
- (void) addFileTransfer:(NSString *) identifier withUser:(NSString *) user forConnection:(MVChatConnection *) connection asType:(MVTransferOperation) type withSize:(unsigned long) size withLocalFile:(NSString *) path;
- (BOOL) updateFileTransfer:(NSString *) identifier withNewTransferedSize:(unsigned long) transfered;
- (BOOL) updateFileTransfer:(NSString *) identifier withStatus:(MVTransferStatus) status;

- (IBAction) stopSelectedTransfer:(id) sender;
- (IBAction) clearFinishedTransfers:(id) sender;
- (IBAction) revealSelectedFile:(id) sender;
@end
