#import "CQInstapaperController.h"

#import "CQKeychain.h"

NSString *const CQBookmarkingServiceInstapaper = @"CQBookmarkingServiceInstapaper";

@implementation CQInstapaperController
+ (NSString *) serviceName {
	return @"Instapaper";
}

#pragma mark -

+ (void) setUsername:(NSString *) username password:(NSString *) password {
	[[CQKeychain standardKeychain] setPassword:username forServer:@"instapaper-username" area:@"bookmarking"];
	[[CQKeychain standardKeychain] setPassword:password forServer:@"instapaper-password" area:@"bookmarking"];
}

+ (NSInteger) authenticationErrorStatusCode {
	return 403;
}

#pragma mark -

+ (void) bookmarkLink:(NSString *) link {
	link = [link stringByEncodingIllegalURLCharacters];
	NSString *username = [[[CQKeychain standardKeychain] passwordForServer:@"instapaper-username" area:@"bookmarking"] stringByEncodingIllegalURLCharacters];
	NSString *password = [[[CQKeychain standardKeychain] passwordForServer:@"instapaper-password" area:@"bookmarking"] stringByEncodingIllegalURLCharacters];
	NSString *urlString = [NSString stringWithFormat:@"https://www.instapaper.com/api/add?username=%@&password=%@&url=%@&auto_title=1", username, password, link];

	[NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.] queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
		[self handleBookmarkingResponse:response withData:data forLink:link];
	}];
}
@end
