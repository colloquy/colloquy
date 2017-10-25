#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

@class MVChatUser;

COLLOQUY_EXPORT extern NSString *MVDownloadFileTransferOfferNotification;
COLLOQUY_EXPORT extern NSString *MVFileTransferDataTransferredNotification;
COLLOQUY_EXPORT extern NSString *MVFileTransferStartedNotification;
COLLOQUY_EXPORT extern NSString *MVFileTransferFinishedNotification;
COLLOQUY_EXPORT extern NSString *MVFileTransferErrorOccurredNotification;

COLLOQUY_EXPORT extern NSString *MVFileTransferErrorDomain;

typedef NS_ENUM(OSType, MVFileTransferStatus) {
	MVFileTransferDoneStatus = 'trDn',
	MVFileTransferNormalStatus = 'trNo',
	MVFileTransferHoldingStatus = 'trHo',
	MVFileTransferStoppedStatus = 'trSt',
	MVFileTransferErrorStatus = 'trEr'
};

typedef NS_ENUM(NSInteger, MVFileTransferError) {
	MVFileTransferConnectionError = -1,
	MVFileTransferFileCreationError = -2,
	MVFileTransferFileOpenError = -3,
	MVFileTransferAlreadyExistsError = -4,
	MVFileTransferUnexpectedlyEndedError = -5,
	MVFileTransferKeyAgreementError = -6
};

static inline NSString *NSStringFromMVFileTransferStatus(MVFileTransferStatus status);
static inline NSString *NSStringFromMVFileTransferStatus(MVFileTransferStatus status) {
	switch(status) {
	case MVFileTransferDoneStatus: return @"trDn";
	case MVFileTransferNormalStatus: return @"trNo";
	case MVFileTransferHoldingStatus: return @"trHo";
	case MVFileTransferStoppedStatus: return @"trSt";
	case MVFileTransferErrorStatus: return @"trEr";
	}
}

COLLOQUY_EXPORT
@interface MVFileTransfer : NSObject

#if __has_feature(objc_class_property)
@property (class) NSRange fileTransferPortRange;
@property (class, getter=isAutoPortMappingEnabled) BOOL autoPortMappingEnabled;
#else
+ (void) setFileTransferPortRange:(NSRange) range;
+ (NSRange) fileTransferPortRange;

+ (void) setAutoPortMappingEnabled:(BOOL) enable;
+ (BOOL) isAutoPortMappingEnabled;
#endif

- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithUser:(MVChatUser *) user NS_DESIGNATED_INITIALIZER;

@property(readonly, getter=isUpload) BOOL upload;
@property(readonly, getter=isDownload) BOOL download;
@property(readonly, getter=isPassive) BOOL passive;
@property(readonly) MVFileTransferStatus status;
@property(strong, readonly) NSError *lastError;

@property(readonly) unsigned long long finalSize;
@property(readonly) unsigned long long transferred;

@property(strong, readonly) NSDate *startDate;
@property(readonly) unsigned long long startOffset;

@property(strong, readonly) NSString *host;
@property(readonly) unsigned short port;

@property(strong, readonly) MVChatUser *user;

- (void) cancel;
@end

#pragma mark -

COLLOQUY_EXPORT
@interface MVUploadFileTransfer : MVFileTransfer {
@protected
	NSString *_source;
}
+ (nullable instancetype) transferWithSourceFile:(NSString *) path toUser:(MVChatUser *) user passively:(BOOL) passive;

@property(strong, readonly) NSString *source;
@end

#pragma mark -

COLLOQUY_EXPORT
@interface MVDownloadFileTransfer : MVFileTransfer {
@protected
	BOOL _rename;
	NSString *_destination;
	NSString *_originalFileName;
}
@property(copy) NSString *destination;
@property(strong, readonly) NSString *originalFileName;

- (void) setDestination:(NSString *) path renameIfFileExists:(BOOL) allow;

- (void) reject;

- (void) accept;
- (void) acceptByResumingIfPossible:(BOOL) resume;
@end

NS_ASSUME_NONNULL_END
