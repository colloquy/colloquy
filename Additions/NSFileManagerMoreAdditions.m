#import "NSFileManagerMoreAdditions.h"

@implementation NSFileManager (MoreAdditions)
// Image formats from https://developer.apple.com/library/ios/#documentation/uikit/reference/UIImage_Class/Reference/Reference.html
+ (BOOL) isValidImageFormat:(NSString *) file {
	static NSArray *validExtensions = nil;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		validExtensions = [[NSArray alloc] initWithObjects:@"tiff", @"tif", @"jpg", @"jpeg", @"gif", @"png", @"bmp", @"bmpf", @"ico", @"cur", @"xbm", nil];
	});

	return [validExtensions containsObject:[file.pathExtension lowercaseString]];
}

// Audio and video formats from http://developer.apple.com/library/ios/DOCUMENTATION/AppleApplications/Reference/SafariWebContent/SafariWebContent.pdf
+ (BOOL) isValidAudioFormat:(NSString *) file {
	static NSArray *validExtensions = nil;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		validExtensions = [[NSArray alloc] initWithObjects:@"aiff", @"aif", @"aifc", @"cdda", @"amr", @"mp3", @"swa", @"mpeg", @"mpg", @"mp3", @"m4a", @"m4b", @"m4p", nil];
	});

	return [validExtensions containsObject:[file.pathExtension lowercaseString]];
}

+ (BOOL) isValidVideoFormat:(NSString *) file {
	static NSArray *validExtensions = nil;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		validExtensions = [[NSArray alloc] initWithObjects:@"3gp", @"3gpp", @"3g2", @"3gp2", @"mp4", @"mov", @"qt", @"mqv", @"m4v", nil];
	});

	return [validExtensions containsObject:[file.pathExtension lowercaseString]];
}

@end
