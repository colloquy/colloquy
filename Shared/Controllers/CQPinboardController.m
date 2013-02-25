#import "CQPinboardController.h"

#import "CQKeychain.h"

NSString *const CQBookmarkingServicePinboard = @"CQBookmarkingServicePinboard";

@implementation CQPinboardController
+ (NSString *) serviceName {
	return @"Pinboard";
}

#pragma mark -

+ (void) setUsername:(NSString *) username password:(NSString *) password {
	[[CQKeychain standardKeychain] setPassword:username forServer:@"pinboard-username" area:@"bookmarking"];
	[[CQKeychain standardKeychain] setPassword:password forServer:@"pinboard-password" area:@"bookmarking"];
}

+ (NSInteger) authenticationErrorStatusCode {
	return 401;
}

#pragma mark -

+ (void) bookmarkLink:(NSString *) link {
	link = [link stringByEncodingIllegalURLCharacters];
	NSString *username = [[CQKeychain standardKeychain] passwordForServer:@"pinboard-username" area:@"bookmarking"];
	NSString *password = [[CQKeychain standardKeychain] passwordForServer:@"pinboard-password" area:@"bookmarking"];
	NSString *urlString = [NSString stringWithFormat:@"https://%@:%@@api.pinboard.in/v1/posts/add?url=%@&description=%@", username, password, link, link];

	[NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.] queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
		[self handleBookmarkingResponse:response withData:data forLink:link];
	}];
}
@end
