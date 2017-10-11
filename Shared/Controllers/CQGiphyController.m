//
//  CQGiphyController.m
//  Colloquy (iOS)
//
//  Created by Zachary on 1/26/16.
//  Copyright © 2016 Colloquy Project. All rights reserved.
//

#import "CQGiphyController.h"

NS_ASSUME_NONNULL_BEGIN

@interface CQGiphyResult ()
@property (copy, readwrite) NSURL *GIFURL;
@property (copy, readwrite) NSURL *mp4URL;
@end

@implementation CQGiphyResult
@end

#pragma mark -

@implementation CQGiphyController
- (void) searchFor:(NSString *) term completion:(void (^)(CQGiphyResult *__nullable result)) completion {
	NSString *giphyIdentifier = @"dc6zaTOxFJmzC"; // public beta
	NSString *escapedTerm = [term stringByReplacingOccurrencesOfString:@" " withString:@"+"];
	NSString *urlString = [NSString stringWithFormat:@"http://api.giphy.com/v1/gifs/random?tag=%@&api_key=%@", escapedTerm, giphyIdentifier];

	[[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:urlString] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
		if ((HTTPResponse.statusCode / 100) != 2) {
			dispatch_async(dispatch_get_main_queue(), ^{
				completion(nil);
			});

			return;
		}

		NSDictionary <NSString *, id> *results = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
		NSDictionary <NSString *, id> *item = results[@"data"];

		CQGiphyResult *result = [[CQGiphyResult alloc] init];
		result.GIFURL = [NSURL URLWithString:item[@"image_url"]];
		result.mp4URL = [NSURL URLWithString:item[@"image_mp4_url"]];

		dispatch_async(dispatch_get_main_queue(), ^{
			completion(result);
		});
	}] resume];
}
@end

NS_ASSUME_NONNULL_END
