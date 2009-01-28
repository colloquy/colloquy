//
//  UIImageAdditions.m
//  Mobile Colloquy
//
//  Created by August Joki on 1/25/09.
//  Copyright 2009 Concinnous Software. All rights reserved.
//

#import "UIImageAdditions.h"
#import <Foundation/Foundation.h>


static NSArray *validExtensions = nil;

@implementation UIImage (UIImageAdditions)

+ (BOOL)isValidImageFormat:(NSString *)file;
{
	if (validExtensions == nil) {
		validExtensions = [[NSArray alloc] initWithObjects:@"tiff", @"tif", @"jpg", @"jpeg", @"gif", @"png", @"bmp", @"bmpf", @"ico", @"cur", @"xbm", nil];
	}
	NSString *extension = [[file pathExtension] lowercaseString];
	return [validExtensions containsObject:extension];
}

@end
