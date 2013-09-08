#import "CQBookmarkingController.h"

NSString *const CQBookmarkingDidSaveLinkNotification = @"CQBookmarkingDidSaveLinkNotification";
NSString *const CQBookmarkingDidNotSaveLinkNotification = @"CQBookmarkingDidNotSaveLinkNotification";

NSString *const CQBookmarkingErrorDomain = @"CQBookmarkingErrorDomain";

#import "CQDeliciousController.h"
#import "CQInstapaperController.h"
#import "CQPinboardController.h"
#import "CQPocketController.h"

#import "CQKeychain.h"

static NSString *bookmarkingService;

@implementation CQBookmarkingController
+ (void) userDefaultsChanged {
	bookmarkingService = [[[NSUserDefaults standardUserDefaults] objectForKey:@"CQBookmarkingService"] copy];
}

+ (void) initialize {
	static BOOL userDefaultsInitialized = NO;

	if (userDefaultsInitialized)
		return;

	userDefaultsInitialized = YES;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDefaultsChanged) name:NSUserDefaultsDidChangeNotification object:nil];

	[self userDefaultsChanged];

}

#pragma mark -

+ (Class <CQBookmarking>) activeService {
	if ([bookmarkingService isEqualToString:CQBookmarkingServiceDelicious])
		return [CQDeliciousController class];
	if ([bookmarkingService isEqualToString:CQBookmarkingServiceInstapaper])
		return [CQInstapaperController class];
	if ([bookmarkingService isEqualToString:CQBookmarkingServicePinboard])
		return [CQPinboardController class];
	if ([bookmarkingService isEqualToString:CQBookmarkingServicePocket])
		return [CQPocketController class];
	return nil;
}

+ (void) handleBookmarkingOfLink:(NSString *) link {
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:link] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.];
	if (![NSURLConnection canHandleRequest:request]) {
		NSError *error = [NSError errorWithDomain:CQBookmarkingErrorDomain code:CQBookmarkingErrorGeneric userInfo:nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:CQBookmarkingDidNotSaveLinkNotification object:nil userInfo:@{
			@"error": error, @"service": [[self class] serviceName]
		}];

		return;
	}

	[NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
		[self handleBookmarkingResponse:response withData:data forLink:link];
	}];
}

+ (void) handleBookmarkingResponse:(NSURLResponse *) response withData:(NSData *) data forLink:(NSString *) link {
	NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
	NSInteger statusCode = HTTPResponse.statusCode;
	if (!statusCode) {
		NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		NSScanner *scanner = [NSScanner scannerWithString:responseString];
		[scanner scanInteger:&statusCode];
	}

	if ((statusCode / 100) == 2) { // 200 (OK), 201 (Created) and 204 (No Content) are all used to indicate success
		[[NSNotificationCenter defaultCenter] postNotificationName:CQBookmarkingDidSaveLinkNotification object:link];
	} else {
		Class <CQBookmarking> class = [self class];
		NSError *error = nil;

		if (!statusCode || statusCode == [class authenticationErrorStatusCode]) { // we've been rejected, reauthorize
			error = [NSError errorWithDomain:CQBookmarkingErrorDomain code:CQBookmarkingErrorAuthorization userInfo:nil];

			NSString *serviceName = [[class serviceName] lowercaseString];
			[[CQKeychain standardKeychain] removePasswordForServer:[NSString stringWithFormat:@"%@-username", serviceName] area:@"bookmarking"];
			[[CQKeychain standardKeychain] removePasswordForServer:[NSString stringWithFormat:@"%@-password", serviceName] area:@"bookmarking"];
			[[CQKeychain standardKeychain] removePasswordForServer:[NSString stringWithFormat:@"%@-token", serviceName] area:@"bookmarking"];
		} else if ((statusCode / 100) == 5) {
			error = [NSError errorWithDomain:CQBookmarkingErrorDomain code:CQBookmarkingErrorAuthorization userInfo:nil];
		} else error = [NSError errorWithDomain:CQBookmarkingErrorDomain code:CQBookmarkingErrorGeneric userInfo:nil];

		[[NSNotificationCenter defaultCenter] postNotificationName:CQBookmarkingDidNotSaveLinkNotification object:link userInfo:@{
			@"error": error, @"service": [class serviceName]
		}];
	}
}
@end
