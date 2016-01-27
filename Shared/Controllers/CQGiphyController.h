NS_ASSUME_NONNULL_BEGIN

@interface CQGiphyResult : NSObject
@property (copy, readonly) NSURL *GIFURL;
@property (copy, readonly) NSURL *mp4URL;
@end

@interface CQGiphyController : NSObject
- (void) searchFor:(NSString *) term completion:(void (^)(CQGiphyResult *__nullable result)) completion;
@end

NS_ASSUME_NONNULL_END
