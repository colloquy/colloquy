#import "NSAttributedStringAdditions.h"
#import "NSStringAdditions.h"
#import <Cocoa/Cocoa.h>

@implementation NSMutableString (NSMutableStringReplaceAdditions)
- (void) replaceString:(NSString *) search withString:(NSString *) replace maxTimes:(unsigned) max {
	NSScanner *scanner = [NSScanner scannerWithString:self];
	NSRange range;
	unsigned i = 0;
	while( ! [scanner isAtEnd] ) {
		[scanner scanUpToString:search intoString:nil];
		range = [[self substringFromIndex:[scanner scanLocation]] rangeOfString:search];
		if( range.length && ( ( i < max && max ) || ! max ) ) {
			i++;
			[self replaceCharactersInRange:NSMakeRange( range.location + [scanner scanLocation], range.length ) withString:replace];
			scanner = [NSScanner scannerWithString:self];
			[scanner setScanLocation:[scanner scanLocation] + range.location + [replace length]];
		} else if( i >= max && max ) break;
	}
}
@end

@implementation NSString (NSStringHTMLAdditions)
+ (NSString *) stringWithHTMLStripedFromString:(NSString *) aString {
	return [NSString stringWithHTMLStripedFromString:aString encoding:NSUTF8StringEncoding];
}

+ (NSString *) stringWithHTMLStripedFromString:(NSString *) aString encoding:(NSStringEncoding) encoding {
	NSData *data = [aString dataUsingEncoding:encoding allowLossyConversion:YES];
	NSAttributedString *attr = [NSAttributedString attributedStringWithHTML:data usingEncoding:encoding documentAttributes:NULL];
	return [[[attr string] retain] autorelease];
}
@end

@implementation NSString (NSStringLengthAdditions)
- (unsigned long) UTF8StringByteLength {
	return ( [self UTF8String] ? strlen( [self UTF8String] ) : 0 );
}
@end
