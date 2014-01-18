#import "CQSafariReadingListController.h"

#import <SafariServices/SafariServices.h>

NSString *const CQBookmarkingServiceSafariReadingList = @"CQBookmarkingServiceSafariReadingList";

@implementation CQSafariReadingListController
+ (NSString *) serviceName {
	return @"Safari Reading	List";
}

#pragma mark -

+ (void) bookmarkLink:(NSString *) link {
	if (![UIDevice currentDevice].isSystemSeven)
		return;

	if (![link hasPrefix:@"http"])
		link = [@"http://" stringByAppendingString:link];

	NSURL *linkURL = [NSURL URLWithString:link];
	if (![SSReadingList supportsURL:linkURL]) {
		NSError *error = [NSError errorWithDomain:CQBookmarkingErrorDomain code:CQBookmarkingErrorInvalidLink userInfo:nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:CQBookmarkingDidNotSaveLinkNotification object:link userInfo:@{
			@"error": error, @"service": [self serviceName]
		}];
	}

	NSError *error = nil;
	if ([[SSReadingList defaultReadingList] addReadingListItemWithURL:linkURL title:nil previewText:nil error:&error])
		[[NSNotificationCenter defaultCenter] postNotificationName:CQBookmarkingDidSaveLinkNotification object:link];
	else [[NSNotificationCenter defaultCenter] postNotificationName:CQBookmarkingDidNotSaveLinkNotification object:link userInfo:@{
		@"error": error, @"service": [self serviceName]
	}];
}
@end
