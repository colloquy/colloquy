//
//  NSString+MaddsPathExtensions.m
//  Colloquy (Old)
//
//  Created by C.W. Betts on 2/6/17.
//
//

#import "MaddsPathExtensions.h"

@implementation NSString (MaddsPathExtensions)
- (NSString*)stringByAppendingPathComponents:(NSArray<NSString*>*)components
{
	NSString *currentPath = self;
	for (NSString *subPath in components) {
		currentPath = [currentPath stringByAppendingPathComponent:subPath];
	}
	return currentPath;
}
@end

@implementation NSMutableString (MaddsPathExtensions)
- (void)appendPathComponents:(NSArray<NSString*>*)components
{
	NSString *currentPath = [self stringByAppendingPathComponents:components];
	[self setString:currentPath];
}
@end


@implementation NSURL (MaddsPathExtensions)
- (NSURL*)URLByAppendingPathComponents:(NSArray<NSString*>*)components
{
	if (!self.isFileURL) {
		return nil;
	}
	NSURL *currentURL = self;
	for (NSString *subPath in components) {
		currentURL = [currentURL URLByAppendingPathComponent:subPath];
	}
	return currentURL;
}
@end
