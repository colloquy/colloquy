NS_ASSUME_NONNULL_BEGIN

@interface NSFileManager (MoreAdditions)
+ (BOOL) isValidImageFormat:(NSString *) file;
+ (BOOL) isValidAudioFormat:(NSString *) file;
+ (BOOL) isValidVideoFormat:(NSString *) file;
@end

NS_ASSUME_NONNULL_END
