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
	return ( [self UTF8String] ? strlen( [self UTF8String] ) : 0 );
}
@end
