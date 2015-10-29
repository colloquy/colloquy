NS_ASSUME_NONNULL_BEGIN

@interface CQIntroductoryGIFFrameOperation : NSOperation
- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithURL:(NSURL *) url NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) NSURL *url;

@property (nonatomic, readonly) NSData *__nullable introductoryFrameImageData;
#if TARGET_OS_IPHONE
@property (nonatomic, readonly) UIImage *__nullable introductoryFrameImage;
#else
@property (nonatomic, readonly) NSImage *__nullable introductoryFrameImage;
#endif

// - If you want a block-based completion handler, remember that -completionBlock is already built into NSOperation.
// - Note: Target-action is faster. It is guaranteed to be called as soon as the operation is completed, while completionBlock has
//   to wait for KVO notifications to come in.
@property (weak) id target;
@property SEL action; // Signature: - (void) operationCompleted:(CQIntroductoryGIFFrameOperation *) operation;
@property (strong) id userInfo;

@property BOOL loggingEnabled;
@end

NS_ASSUME_NONNULL_END
