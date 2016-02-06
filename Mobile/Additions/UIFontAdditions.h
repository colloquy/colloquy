#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^CQRemoteFontCompletionHandler)(NSString *, UIFont *__nullable); // font is nil on failure

extern NSString *const CQRemoteFontCourierDidLoadFontListNotification;
	extern NSString *const CQRemoteFontCourierFontListKey;

extern NSString *const CQRemoteFontCourierFontLoadingDidSucceedNotification;
extern NSString *const CQRemoteFontCourierFontLoadingDidFailNotification;
	extern NSString *const CQRemoteFontCourierFontLoadingFontNameKey;
	extern NSString *const CQRemoteFontCourierFontLoadingFontKey;

@interface UIFont (Additions)
+ (void) cq_availableRemoteFontNames:(void (^)(NSArray *__nullable fontNames)) completion; // usually synchronous. might not be if the cache expires (and needs updating)

+ (void) cq_loadRemoteFontWithName:(NSString *) fontName completionHandler:(CQRemoteFontCompletionHandler __nullable) completionHandler;
@end

NS_ASSUME_NONNULL_END
