#import "NSStringAdditions.h"
#import <Cocoa/Cocoa.h>

@implementation NSString (NSStringAdditions)
+ (NSString *) mimeCharsetTagFromStringEncoding:(NSStringEncoding) encoding {
	switch( encoding ) {
	default:
	case NSASCIIStringEncoding:
	case NSNonLossyASCIIStringEncoding:
		return @"us-ascii";
		break;
	case NSUTF8StringEncoding:
		return @"utf-8";
		break;
	case NSISOLatin1StringEncoding:
		return @"iso-8859-1";
		break;
	case 0x80000203:
		return @"iso-8859-3";
		break;
	case 0x8000020F:
		return @"iso-8859-9";
		break;
	case NSWindowsCP1252StringEncoding:
		return @"windows-1252";
		break;
	case NSISOLatin2StringEncoding:
		return @"iso-8859-2";
		break;
	case 0x80000204:
		return @"iso-8859-4";
		break;
	case NSWindowsCP1250StringEncoding:
		return @"windows-1250";
		break;
	case 0x80000A02:
		return @"KOI8-R";
		break;
	case 0x80000205:
		return @"iso-8859-5";
		break;
	case NSWindowsCP1251StringEncoding:
		return @"windows-1251";
		break;
	case 0x80000A01:
		return @"Shift_JIS";
		break;
	case NSISO2022JPStringEncoding:
		return @"iso-2022-jp";
		break;
	case NSJapaneseEUCStringEncoding:
		return @"EUC-JP";
		break;
	}
}

- (unsigned long) UTF8StringByteLength {
	const char *str = [self UTF8String];
	return ( str ? strlen( str ) : 0 );
}

- (NSString *) stringByEncodingXMLSpecialCharactersAsEntities {
	NSMutableString *result = [self mutableCopy];
	[result encodeXMLSpecialCharactersAsEntities];
	NSString *immutableResult = [NSString stringWithString:result];
	[result release];
	return immutableResult;
}

- (NSString *) stringByDecodingXMLSpecialCharacterEntities {
	NSMutableString *result = [self mutableCopy];
	[result decodeXMLSpecialCharacterEntities];
	NSString *immutableResult = [NSString stringWithString:result];
	[result release];
	return immutableResult;
}

- (NSString *) stringByEscapingCharactersInSet:(NSCharacterSet *) set {
	NSMutableString *result = [self mutableCopy];
	[result escapeCharactersInSet:set];
	NSString *immutableResult = [NSString stringWithString:result];
	[result release];
	return immutableResult;
}
@end

#pragma mark -

@implementation NSMutableString (NSMutableStringAdditions)
- (void) encodeXMLSpecialCharactersAsEntities {
	[self replaceOccurrencesOfString:@"&" withString:@"&amp;" options:NSLiteralSearch range:NSMakeRange( 0, [self length] )];
	[self replaceOccurrencesOfString:@"<" withString:@"&lt;" options:NSLiteralSearch range:NSMakeRange( 0, [self length] )];
	[self replaceOccurrencesOfString:@">" withString:@"&gt;" options:NSLiteralSearch range:NSMakeRange( 0, [self length] )];
	[self replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:NSLiteralSearch range:NSMakeRange( 0, [self length] )];
	[self replaceOccurrencesOfString:@"'" withString:@"&apos;" options:NSLiteralSearch range:NSMakeRange( 0, [self length] )];
}

- (void) decodeXMLSpecialCharacterEntities {
	[self replaceOccurrencesOfString:@"&amp;" withString:@"&" options:NSLiteralSearch range:NSMakeRange( 0, [self length] )];
	[self replaceOccurrencesOfString:@"&lt;" withString:@"<" options:NSLiteralSearch range:NSMakeRange( 0, [self length] )];
	[self replaceOccurrencesOfString:@"&gt;" withString:@">" options:NSLiteralSearch range:NSMakeRange( 0, [self length] )];
	[self replaceOccurrencesOfString:@"&quot;" withString:@"\"" options:NSLiteralSearch range:NSMakeRange( 0, [self length] )];
	[self replaceOccurrencesOfString:@"&apos;" withString:@"'" options:NSLiteralSearch range:NSMakeRange( 0, [self length] )];
}

- (void) escapeCharactersInSet:(NSCharacterSet *) set {
	NSScanner *scanner = [[NSScanner alloc] initWithString:self];
	int offset = 0;
	while( ! [scanner isAtEnd] ) {
		[scanner scanUpToCharactersFromSet:set intoString:nil];
		if( ! [scanner isAtEnd] ) {
			[self insertString:@"\\" atIndex:[scanner scanLocation] + offset++];
			[scanner setScanLocation:[scanner scanLocation] + 1];
		}
	}
	[scanner release];
}
@end