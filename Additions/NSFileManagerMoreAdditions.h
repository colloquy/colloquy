@interface NSFileManager (MoreAdditions)
+ (BOOL) isValidImageFormat:(NSString *) file;
+ (BOOL) isValidAudioFormat:(NSString *) file;
+ (BOOL) isValidVideoFormat:(NSString *) file;
@end
