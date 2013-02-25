extern NSString *const CQBookmarkingDidSaveLinkNotification;
extern NSString *const CQBookmarkingDidNotSaveLinkNotification;

typedef enum {
	CQBookmarkingErrorGeneric,
	CQBookmarkingErrorAuthorization,
	CQBookmarkingErrorServer
} CQBookmarkingError;

extern NSString *const CQBookmarkingErrorDomain;

@protocol CQBookmarking <NSObject>
@required
+ (NSString *) serviceName;

+ (NSInteger) authenticationErrorStatusCode;

+ (void) bookmarkLink:(NSString *) link;

@optional
+ (void) authorize;
+ (void) setUsername:(NSString *) username password:(NSString *) password;
@end

@interface CQBookmarkingController : NSObject
+ (Class <CQBookmarking>) activeService;

+ (void) handleBookmarkingResponse:(NSURLResponse *) response withData:(NSData *) data forLink:(NSString *) link;
@end
