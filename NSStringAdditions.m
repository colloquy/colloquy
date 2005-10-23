#import "NSStringAdditions.h"
#include <sys/time.h>

@implementation NSString (NSStringAdditions)
+ (NSString *) locallyUniqueString {
	struct timeval tv;
    gettimeofday( &tv, NULL );

	unsigned int m = 36; // base (denominator)
	unsigned int q = [[NSProcessInfo processInfo] processIdentifier] ^ tv.tv_usec; // input (quotient)
	unsigned int r = 0; // remainder

	NSMutableString *uniqueId = [[NSMutableString allocWithZone:nil] initWithCapacity:10];
	[uniqueId appendFormat:@"%c", 'A' + ( random() % 26 )]; // always have a random letter first (more ambiguity)

	#define baseConvert	do { \
		r = q % m; \
		q = q / m; \
		if( r >= 10 ) r = 'A' + ( r - 10 ); \
		else r = '0' + r; \
		[uniqueId appendFormat:@"%c", r]; \
	} while( q ) \

	baseConvert;

	q = ( tv.tv_sec - 1104555600 ); // subtract 35 years, we only care about post Jan 1 2005
	r = 0;

	baseConvert;

	#undef baseConvert;

	return [uniqueId autorelease];
}

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
	case 0x80000208:
		return @"iso-8859-8";
		break;
	case 0x80000005:
		return @"x-mac-hebrew";
		break;
	case 0x80000505:
		return @"windows-1255";
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

+ (unsigned long) scriptTypedEncodingFromStringEncoding:(NSStringEncoding) encoding {
	switch( encoding ) {
		default:
		case NSUTF8StringEncoding: return 'utF8';
		case NSASCIIStringEncoding: return 'ascI';
		case NSNonLossyASCIIStringEncoding: return 'nlAs';

		case NSISOLatin1StringEncoding: return 'isL1';
		case NSISOLatin2StringEncoding: return 'isL2';
		case (NSStringEncoding) 0x80000203: return 'isL3';
		case (NSStringEncoding) 0x80000204: return 'isL4';
		case (NSStringEncoding) 0x80000205: return 'isL5';
		case (NSStringEncoding) 0x8000020F: return 'isL9';

		case NSWindowsCP1250StringEncoding: return 'cp50';
		case NSWindowsCP1251StringEncoding: return 'cp51';
		case NSWindowsCP1252StringEncoding: return 'cp52';

		case NSMacOSRomanStringEncoding: return 'mcRo';
		case (NSStringEncoding) 0x8000001D: return 'mcEu';
		case (NSStringEncoding) 0x80000007: return 'mcCy';
		case (NSStringEncoding) 0x80000001: return 'mcJp';
		case (NSStringEncoding) 0x80000019: return 'mcSc';
		case (NSStringEncoding) 0x80000002: return 'mcTc';
		case (NSStringEncoding) 0x80000003: return 'mcKr';

		case (NSStringEncoding) 0x80000A02: return 'ko8R';

		case (NSStringEncoding) 0x80000421: return 'wnSc';
		case (NSStringEncoding) 0x80000423: return 'wnTc';
		case (NSStringEncoding) 0x80000422: return 'wnKr';

		case NSJapaneseEUCStringEncoding: return 'jpUC';
		case (NSStringEncoding) 0x80000A01: return 'sJiS';
		case NSShiftJISStringEncoding: return 'sJiS';

		case (NSStringEncoding) 0x80000940: return 'krUC';
		case (NSStringEncoding) 0x80000930: return 'scUC';
		case (NSStringEncoding) 0x80000931: return 'tcUC';

		case (NSStringEncoding) 0x80000632: return 'gb30';
		case (NSStringEncoding) 0x80000631: return 'gbKK';
		case (NSStringEncoding) 0x80000A03: return 'biG5';
		case (NSStringEncoding) 0x80000A06: return 'bG5H';
	}

	return 'utF8'; // default encoding
}

+ (NSStringEncoding) stringEncodingFromScriptTypedEncoding:(unsigned long) encoding {
	switch( encoding ) {
		default:
		case 'utF8': return NSUTF8StringEncoding;
		case 'ascI': return NSASCIIStringEncoding;
		case 'nlAs': return NSNonLossyASCIIStringEncoding;

		case 'isL1': return NSISOLatin1StringEncoding;
		case 'isL2': return NSISOLatin2StringEncoding;
		case 'isL3': return (NSStringEncoding) 0x80000203;
		case 'isL4': return (NSStringEncoding) 0x80000204;
		case 'isL5': return (NSStringEncoding) 0x80000205;
		case 'isL9': return (NSStringEncoding) 0x8000020F;

		case 'cp50': return NSWindowsCP1250StringEncoding;
		case 'cp51': return NSWindowsCP1251StringEncoding;
		case 'cp52': return NSWindowsCP1252StringEncoding;

		case 'mcRo': return NSMacOSRomanStringEncoding;
		case 'mcEu': return (NSStringEncoding) 0x8000001D;
		case 'mcCy': return (NSStringEncoding) 0x80000007;
		case 'mcJp': return (NSStringEncoding) 0x80000001;
		case 'mcSc': return (NSStringEncoding) 0x80000019;
		case 'mcTc': return (NSStringEncoding) 0x80000002;
		case 'mcKr': return (NSStringEncoding) 0x80000003;

		case 'ko8R': return (NSStringEncoding) 0x80000A02;

		case 'wnSc': return (NSStringEncoding) 0x80000421;
		case 'wnTc': return (NSStringEncoding) 0x80000423;
		case 'wnKr': return (NSStringEncoding) 0x80000422;

		case 'jpUC': return NSJapaneseEUCStringEncoding;
		case 'sJiS': return (NSStringEncoding) 0x80000A01;

		case 'krUC': return (NSStringEncoding) 0x80000940;
		case 'scUC': return (NSStringEncoding) 0x80000930;
		case 'tcUC': return (NSStringEncoding) 0x80000931;

		case 'gb30': return (NSStringEncoding) 0x80000632;
		case 'gbKK': return (NSStringEncoding) 0x80000631;
		case 'biG5': return (NSStringEncoding) 0x80000A03;
		case 'bG5H': return (NSStringEncoding) 0x80000A06;
	}

	return NSUTF8StringEncoding; // default encoding
}

#pragma mark -

- (id) initWithBytes:(const void *) bytes encoding:(NSStringEncoding) encoding {
	if( bytes ) {
		id ret = [self initWithBytes:bytes length:strlen( bytes ) encoding:encoding];
		if( ! ret ) ret = [self initWithCString:bytes];
		if( ! ret ) [self release];
		return ret;
	}

	[self release];
	return nil;
}

+ (id) stringWithBytes:(const void *) bytes encoding:(NSStringEncoding) encoding {
	return [[[self allocWithZone:nil] initWithBytes:bytes encoding:encoding] autorelease];
}

#pragma mark -

- (const char *) bytesUsingEncoding:(NSStringEncoding) encoding allowLossyConversion:(BOOL) lossy {
	NSMutableData *ret = [[[self dataUsingEncoding:encoding allowLossyConversion:lossy] mutableCopyWithZone:nil] autorelease];
	[ret appendBytes:"\0" length:1];
	return [ret bytes];
}

- (const char *) bytesUsingEncoding:(NSStringEncoding) encoding {
	return [self bytesUsingEncoding:encoding allowLossyConversion:NO];
}

#pragma mark -

- (NSString *) stringByEncodingXMLSpecialCharactersAsEntities {
	NSMutableString *result = [self mutableCopyWithZone:nil];
	[result encodeXMLSpecialCharactersAsEntities];
	return [result autorelease];
}

- (NSString *) stringByDecodingXMLSpecialCharacterEntities {
	NSMutableString *result = [self mutableCopyWithZone:nil];
	[result decodeXMLSpecialCharacterEntities];
	return [result autorelease];
}

#pragma mark -

- (NSString *) stringByEscapingCharactersInSet:(NSCharacterSet *) set {
	NSMutableString *result = [self mutableCopyWithZone:nil];
	[result escapeCharactersInSet:set];
	return [result autorelease];
}

#pragma mark -

- (NSString *) stringByEncodingIllegalURLCharacters {
	return [(NSString *)CFURLCreateStringByAddingPercentEscapes( NULL, (CFStringRef)self, NULL, CFSTR( ",;:/?@&$=|^~`\{}[]" ), kCFStringEncodingUTF8 ) autorelease];
}

- (NSString *) stringByDecodingIllegalURLCharacters {
	return [(NSString *)CFURLCreateStringByReplacingPercentEscapes( NULL, (CFStringRef)self, CFSTR( "" ) ) autorelease];
}

#pragma mark -

- (NSString *) stringByStrippingIllegalXMLCharacters {
	NSMutableString *result = [self mutableCopyWithZone:nil];
	[result stripIllegalXMLCharacters];
	return [result autorelease];
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

#pragma mark -

- (void) escapeCharactersInSet:(NSCharacterSet *) set {
	NSScanner *scanner = [[NSScanner allocWithZone:nil] initWithString:self];
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

#pragma mark -

- (void) encodeIllegalURLCharacters {
	[self setString:[self stringByEncodingIllegalURLCharacters]];
}

- (void) decodeIllegalURLCharacters {
	[self setString:[self stringByDecodingIllegalURLCharacters]];
}

#pragma mark -

- (void) stripIllegalXMLCharacters {
	NSMutableCharacterSet *illegalSet = [[[NSCharacterSet characterSetWithRange:NSMakeRange( 0, 0x1f )] mutableCopyWithZone:nil] autorelease];
	[illegalSet addCharactersInRange:NSMakeRange( 0x7f, 1 )];
	[illegalSet addCharactersInRange:NSMakeRange( 0xfffe, 1 )];
	[illegalSet addCharactersInRange:NSMakeRange( 0xffff, 1 )];

	NSRange range = [self rangeOfCharacterFromSet:illegalSet];
	while( range.location != NSNotFound ) {
		[self deleteCharactersInRange:range];
		range = [self rangeOfCharacterFromSet:illegalSet];
	}
}
@end