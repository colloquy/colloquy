#import "CQPocketController.h"

#import "CQKeychain.h"

#import "NSNotificationAdditions.h"
#import "NSURLSessionAdditions.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const CQBookmarkingServicePocket = @"CQBookmarkingServicePocket";

@implementation CQPocketController
+ (NSString *) serviceName {
	return @"Pocket";
}

+ (NSInteger) authenticationErrorStatusCode {
	return 403;
}

#pragma mark -

+ (NSMutableURLRequest *) _postRequestWithURL:(NSString *) URLString {
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10.];
	request.HTTPMethod = @"POST";
	request.allHTTPHeaderFields = @{ @"X-Accept": @"application/json" };
	return request;
}

+ (NSString *) _consumerKey {
	if ([UIDevice currentDevice].isPadModel)
		return @"Pocket_iPad_Consumer_Key";
	return @"Pocket_iPhone_Consumer_Key";
}

#pragma mark -

+ (void) _postServerErrorNotification {
	NSError *error = [NSError errorWithDomain:CQBookmarkingErrorDomain code:CQBookmarkingErrorServer userInfo:nil];
	[[NSNotificationCenter chatCenter] postNotificationName:CQBookmarkingDidNotSaveLinkNotification object:nil userInfo:@{ @"error": error }];
}

+ (void) _postAuthenticationErrorNotificationForLink:(NSString *) link {
	NSError *error = [NSError errorWithDomain:CQBookmarkingErrorDomain code:CQBookmarkingErrorAuthorization userInfo:nil];
	[[NSNotificationCenter chatCenter] postNotificationName:CQBookmarkingDidNotSaveLinkNotification object:link userInfo:@{ @"error": error }];
}

+ (void) _shouldConvertTokenFromTokenNotification:(NSNotification *) notification {
	NSString *activeCode = [[NSUserDefaults standardUserDefaults] objectForKey:@"CQBookmarkingActivePocketCode"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"CQBookmarkingActivePocketCode"];
	[[NSNotificationCenter chatCenter] removeObserver:self name:@"CQPocketShouldConvertTokenFromTokenNotification" object:nil];

	NSMutableURLRequest *request = [self _postRequestWithURL:@"https://getpocket.com/v3/oauth/authorize"];
	request.HTTPBody = @{ @"consumer_key": [self _consumerKey], @"code": activeCode }.postDataRepresentation;

	NSURLSession *backgroundSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"Pocket"]];
	[[backgroundSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
		if ((HTTPResponse.statusCode / 100) == 2) {
			NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
			[[CQKeychain standardKeychain] setPassword:responseDictionary[@"access_token"] forServer:@"pocket-token" area:@"bookmarking"];
		} else if ((HTTPResponse.statusCode / 100) == 5)
			dispatch_async(dispatch_get_main_queue(), ^{
				[self _postServerErrorNotification];
			});
	}] resume];
}

#pragma mark -

+ (void) authorize {
	NSMutableURLRequest *request = [self _postRequestWithURL:@"https://getpocket.com/v3/oauth/request"];
	request.HTTPBody = @{ @"consumer_key": [self _consumerKey], @"redirect_uri": @"colloquy://redirect" }.postDataRepresentation;

	[[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
		dispatch_async(dispatch_get_main_queue(), ^{
			if ((HTTPResponse.statusCode / 100) == 2) {
				NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
				[[NSUserDefaults standardUserDefaults] setObject:responseDictionary[@"code"] forKey:@"CQBookmarkingActivePocketCode"];

				NSString *URLBase = nil;
				if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"pocket-oauth-v1:///authorize"]])
					URLBase = @"pocket-oauth-v1:///authorize?";
				else URLBase = @"https://getpocket.com/auth/authorize?";

				[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_shouldConvertTokenFromTokenNotification:) name:@"CQPocketShouldConvertTokenFromTokenNotification" object:nil];
				[[UIApplication sharedApplication] openURL:[NSURL URLWithString:[URLBase stringByAppendingFormat:@"request_token=%@&redirect_uri=%@", responseDictionary[@"code"], @"colloquy://redirect"]]];
			} else if ((HTTPResponse.statusCode / 100) == 5)
				[self _postServerErrorNotification];
		});
	}] resume];
}

#pragma mark -

+ (void) bookmarkLink:(NSString *) link {
	NSString *token = [[CQKeychain standardKeychain] passwordForServer:@"pocket-token" area:@"bookmarking"];

	if (!token) {
		[self _postAuthenticationErrorNotificationForLink:link];
		return;
	}

	NSMutableURLRequest *request = [self _postRequestWithURL:@"https://getpocket.com/v3/add"];
	request.HTTPBody = @{ @"url": link, @"consumer_key": [self _consumerKey], @"access_token": token }.postDataRepresentation;

	[[[NSURLSession CQ_backgroundSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		[self handleBookmarkingResponse:response withData:data forLink:link];
	}] resume];
}
@end

NS_ASSUME_NONNULL_END
