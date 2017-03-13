typedef NS_ENUM(NSInteger, CQBookmarkingError) {
	CQBookmarkingErrorGeneric,
	CQBookmarkingErrorAuthorization,
	CQBookmarkingErrorServer,
	CQBookmarkingErrorInvalidLink
};

NS_ASSUME_NONNULL_BEGIN

extern NSString *const CQBookmarkingDidSaveLinkNotification;
extern NSString *const CQBookmarkingDidNotSaveLinkNotification;

extern NSString *const CQBookmarkingErrorDomain;

@protocol CQBookmarking <NSObject>
@required
+ (NSString *) serviceName;

@optional
// required for everything except SafariService
+ (NSInteger) authenticationErrorStatusCode;

+ (void) bookmarkLink:(NSString *) link;

// +authorize is only used for Pocket
+ (void) authorize;
+ (void) setUsername:(NSString *) username password:(NSString *) password;
@end

@interface CQBookmarkingController : NSObject
+ (Class <CQBookmarking> __nullable) activeService;

+ (void) handleBookmarkingOfLink:(NSString *) link;
+ (void) handleBookmarkingResponse:(NSURLResponse *) response withData:(NSData *) data forLink:(NSString *) link;
@end

NS_ASSUME_NONNULL_END
