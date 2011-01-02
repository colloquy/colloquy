@class MVFileTransfer;

@interface MVFileTransferController : NSWindowController {
@private
	NSSet *_safeFileExtentions;
}
+ (NSString *) userPreferredDownloadFolder;
+ (void) setUserPreferredDownloadFolder:(NSString *) path;

+ (MVFileTransferController *) defaultController;

- (void) fileAtPathDidFinish:(NSString *) path;
@end
