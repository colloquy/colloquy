//  Created by August Joki on 1/25/09.
//  Copyright 2009 Concinnous Software. All rights reserved.

#if ENABLE(FILE_TRANSFERS)

#import "UIImageAdditions.h"
#import <Foundation/Foundation.h>



@implementation UIImage (UIImageAdditions)

+ (BOOL)isValidImageFormat:(NSString *)file;
{
	static NSArray *validExtensions = nil;

	if (!validExtensions)
		validExtensions = [[NSArray alloc] initWithObjects:@"tiff", @"tif", @"jpg", @"jpeg", @"gif", @"png", @"bmp", @"bmpf", @"ico", @"cur", @"xbm", nil];
	NSString *extension = [[file pathExtension] lowercaseString];
	return [validExtensions containsObject:extension];
}

@end
#endif
