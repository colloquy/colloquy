#import "CQDeliciousController.h"

#import "CQKeychain.h"

NSString *const CQBookmarkingServiceDelicious = @"CQBookmarkingServiceDelicious";

@implementation CQDeliciousController
+ (NSString *) serviceName {
	return @"Delicious";
}

+ (void) setUsername:(NSString *) username password:(NSString *) password {
	[[CQKeychain standardKeychain] setPassword:username forServer:@"delicious-username" area:@"bookmarking"];
	[[CQKeychain standardKeychain] setPassword:password forServer:@"delicious-password" area:@"bookmarking"];
}

+ (NSInteger) authenticationErrorStatusCode {
	return 401;
}

#pragma mark -

+ (void) bookmarkLink:(NSString *) link {
	link = [link stringByEncodingIllegalURLCharacters];
	NSString *username = [[CQKeychain standardKeychain] passwordForServer:@"delicious-username" area:@"bookmarking"];
	NSString *password = [[CQKeychain standardKeychain] passwordForServer:@"delicious-password" area:@"bookmarking"];
	NSString *urlString = [NSString stringWithFormat:@"https://%@:%@@api.del.icio.us/v1/posts/add?red=api&url=%@&description=%@", username, password, link, link];

	[NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.] queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
		[self handleBookmarkingResponse:response withData:data forLink:link];
	}];
}
@end
