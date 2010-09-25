NSString *MVPrettyFileSize( unsigned long long size );
NSString *MVReadableTime( NSTimeInterval date, BOOL longFormat );

@class MVFileTransfer;

@interface MVFileTransferController : NSWindowController
#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_5
<NSToolbarDelegate, NSOpenSavePanelDelegate>
#endif
{
@private
	IBOutlet NSProgressIndicator *progressBar;
	IBOutlet NSTextField *transferStatus;
	IBOutlet NSTableView *currentFiles;
	NSMutableArray *_transferStorage;
	NSMutableArray *_calculationItems;
	NSTimer *_updateTimer;
	NSSet *_safeFileExtentions;
}
+ (NSString *) userPreferredDownloadFolder;
+ (void) setUserPreferredDownloadFolder:(NSString *) path;

+ (MVFileTransferController *) defaultController;

- (IBAction) showTransferManager:(id) sender;
- (IBAction) hideTransferManager:(id) sender;

- (void) downloadFileAtURL:(NSURL *) url toLocalFile:(NSString *) path;
- (void) addFileTransfer:(MVFileTransfer *) transfer;

- (IBAction) stopSelectedTransfer:(id) sender;
- (IBAction) clearFinishedTransfers:(id) sender;
- (IBAction) revealSelectedFile:(id) sender;
@end
