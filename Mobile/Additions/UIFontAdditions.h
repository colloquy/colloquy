NS_ASSUME_NONNULL_BEGIN

typedef void (^CQRemoteFontCompletionHandler)(NSString *, UIFont *__nullable); // font is nil on failure

extern NSString *CQRemoteFontCourierFontLoadingDidSucceedNotification;
extern NSString *CQRemoteFontCourierFontLoadingDidFailNotification;

extern NSString *CQRemoteFontCourierFontLoadingFontNameKey;
extern NSString *CQRemoteFontCourierFontLoadingFontKey;

@interface UIFont (Additions)
+ (NSArray *) cq_availableRemoteFontNames;
+ (void) cq_loadAllAvailableFonts; // You probably don't want to use this unless you're debugging/testing something

+ (void) cq_loadFontWithName:(NSString *) fontName withCompletionHandler:(__nullable CQRemoteFontCompletionHandler)completionHandler;
@end

NS_ASSUME_NONNULL_END
