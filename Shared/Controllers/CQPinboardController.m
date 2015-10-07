#import "CQPinboardController.h"

#import "CQKeychain.h"

NS_ASSUME_NONNULL_BEGIN

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
	NSString *username = [[[CQKeychain standardKeychain] passwordForServer:@"pinboard-username" area:@"bookmarking"] stringByEncodingIllegalURLCharacters];
	NSString *password = [[[CQKeychain standardKeychain] passwordForServer:@"pinboard-password" area:@"bookmarking"] stringByEncodingIllegalURLCharacters];
	NSString *urlString = [NSString stringWithFormat:@"https://%@:%@@api.pinboard.in/v1/posts/add?url=%@&description=%@", username, password, link, link];

	[self handleBookmarkingOfLink:urlString];
}
@end

NS_ASSUME_NONNULL_END
