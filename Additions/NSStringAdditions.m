#import "NSStringAdditions.h"

#import "NSCharacterSetAdditions.h"
#import "NSScannerAdditions.h"
#import "NSRegularExpressionAdditions.h"

#import <sys/time.h>

NS_ASSUME_NONNULL_BEGIN

struct EmojiEmoticonPair {
	const unichar emoji;
	CFStringRef emoticon;
};

static const struct EmojiEmoticonPair emojiToEmoticonList[] = {
	{ 0xe00e, CFSTR("(Y)") },
	{ 0xe022, CFSTR("<3") },
	{ 0xe023, CFSTR("</3") },
	{ 0xe032, CFSTR("@};-") },
	{ 0xe048, CFSTR(":^)") },
	{ 0xe04e, CFSTR("O:)") },
	{ 0xe056, CFSTR(":)") },
	{ 0xe057, CFSTR(":D") },
	{ 0xe058, CFSTR(":(") },
	{ 0xe059, CFSTR(">:(") },
	{ 0xe05a, CFSTR("~<:)") },
	{ 0xe105, CFSTR(";P") },
	{ 0xe106, CFSTR("(<3") },
	{ 0xe107, CFSTR(":O") },
	{ 0xe108, CFSTR("-_-'") },
	{ 0xe11a, CFSTR(">:)") },
	{ 0xe401, CFSTR(":'(") },
	{ 0xe402, CFSTR(":j") },
	{ 0xe403, CFSTR(":|") },
	{ 0xe404, CFSTR(":-!") },
	{ 0xe405, CFSTR(";)") },
	{ 0xe406, CFSTR("><") },
	{ 0xe407, CFSTR(":X") },
	{ 0xe408, CFSTR(";'(") },
	{ 0xe409, CFSTR(":P") },
	{ 0xe40a, CFSTR(":->") },
	{ 0xe40b, CFSTR(":o") },
	{ 0xe40c, CFSTR(":-&") },
	{ 0xe40d, CFSTR("O.O") },
	{ 0xe40e, CFSTR(":/") },
	{ 0xe40f, CFSTR(":'o") },
	{ 0xe410, CFSTR("x_x") },
	{ 0xe411, CFSTR(":\"o") },
	{ 0xe412, CFSTR(":'D") },
	{ 0xe413, CFSTR(";(") },
	{ 0xe414, CFSTR(":[") },
	{ 0xe415, CFSTR("^-^") },
	{ 0xe416, CFSTR("}:(") },
	{ 0xe417, CFSTR(":-*") },
	{ 0xe418, CFSTR(";-*") },
	{ 0xe421, CFSTR("(N)") },
	{ 0xe445, CFSTR("(~~)") },
	{ 0xe50c, CFSTR("**==") },
	{ 0, nil }
};

static const struct EmojiEmoticonPair emoticonToEmojiList[] = {
// Most Common
	{ 0xe056, CFSTR(":)") },
	{ 0xe056, CFSTR("=)") },
	{ 0xe058, CFSTR(":(") },
	{ 0xe058, CFSTR("=(") },
	{ 0xe405, CFSTR(";)") },
	{ 0xe409, CFSTR(":P") },
	{ 0xe409, CFSTR(":p") },
	{ 0xe409, CFSTR("=P") },
	{ 0xe409, CFSTR("=p") },
	{ 0xe105, CFSTR(";p") },
	{ 0xe105, CFSTR(";P") },
	{ 0xe057, CFSTR(":D") },
	{ 0xe057, CFSTR("=D") },
	{ 0xe403, CFSTR(":|") },
	{ 0xe403, CFSTR("=|") },
	{ 0xe40e, CFSTR(":/") },
	{ 0xe40e, CFSTR(":\\") },
	{ 0xe40e, CFSTR("=/") },
	{ 0xe40e, CFSTR("=\\") },
	{ 0xe414, CFSTR(":[") },
	{ 0xe414, CFSTR("=[") },
	{ 0xe056, CFSTR(":]") },
	{ 0xe056, CFSTR("=]") },
	{ 0xe40b, CFSTR(":o") },
	{ 0xe107, CFSTR(":O") },
	{ 0xe40b, CFSTR("=o") },
	{ 0xe107, CFSTR("=O") },
	{ 0xe107, CFSTR(":0") },
	{ 0xe107, CFSTR("=0") },
	{ 0xe04e, CFSTR("O:)") },
	{ 0xe04e, CFSTR("0:)") },
	{ 0xe04e, CFSTR("o:)") },
	{ 0xe04e, CFSTR("O=)") },
	{ 0xe04e, CFSTR("0=)") },
	{ 0xe04e, CFSTR("o=)") },
	{ 0xe022, CFSTR("<3") },
	{ 0xe023, CFSTR("</3") },
	{ 0xe023, CFSTR("<\3") },
	{ 0xe406, CFSTR("><") },
	{ 0xe40d, CFSTR("O.O") },
	{ 0xe40d, CFSTR("o.o") },
	{ 0xe40d, CFSTR("O.o") },
	{ 0xe40d, CFSTR("o.O") },
	{ 0xe409, CFSTR("XD") },
	{ 0xe409, CFSTR("xD") },
	{ 0xe407, CFSTR(":X") },
	{ 0xe407, CFSTR(":x") },
	{ 0xe407, CFSTR("=X") },
	{ 0xe407, CFSTR("=x") },
	{ 0xe059, CFSTR(">:(") },
	{ 0xe11a, CFSTR(">:)") },
	{ 0xe415, CFSTR("^.^") },
	{ 0xe415, CFSTR("^-^") },
	{ 0xe415, CFSTR("^_^") },

// Less Common
	{ 0xe056, CFSTR("(:") },
	{ 0xe056, CFSTR("(=") },
	{ 0xe056, CFSTR("[:") },
	{ 0xe056, CFSTR("[=") },
	{ 0xe058, CFSTR("):") },
	{ 0xe058, CFSTR(")=") },
	{ 0xe058, CFSTR("]=") },
	{ 0xe058, CFSTR("]:") },
	{ 0xe056, CFSTR(":-)") },
	{ 0xe056, CFSTR("=-)") },
	{ 0xe058, CFSTR(":-(") },
	{ 0xe409, CFSTR(":-P") },
	{ 0xe409, CFSTR(":-p") },
	{ 0xe409, CFSTR("=-P") },
	{ 0xe409, CFSTR("=-p") },
	{ 0xe105, CFSTR(";-p") },
	{ 0xe105, CFSTR(";-P") },
	{ 0xe405, CFSTR(";-)") },
	{ 0xe057, CFSTR(":-D") },
	{ 0xe057, CFSTR("=-D") },
	{ 0xe058, CFSTR("=-(") },
	{ 0xe059, CFSTR(">=(") },
	{ 0xe11a, CFSTR(">=)") },
	{ 0xe414, CFSTR(":-[") },
	{ 0xe414, CFSTR("=-[") },
	{ 0xe107, CFSTR(":-0") },
	{ 0xe107, CFSTR("=-0") },
	{ 0xe04e, CFSTR("O=-)") },
	{ 0xe04e, CFSTR("o=-)") },
	{ 0xe108, CFSTR("-_-'") },
	{ 0xe403, CFSTR("-_-") },
	{ 0xe409, CFSTR("Xd") },
	{ 0xe409, CFSTR("xd") },
	{ 0xe409, CFSTR(";D") },
	{ 0xe409, CFSTR("D:") },
	{ 0xe409, CFSTR("D:<") },
	{ 0xe406, CFSTR(">_<") },
	{ 0xe410, CFSTR("X_X") },
	{ 0xe410, CFSTR("x_x") },
	{ 0xe410, CFSTR("X_x") },
	{ 0xe410, CFSTR("x_X") },
	{ 0xe410, CFSTR("x.x") },
	{ 0xe410, CFSTR("X.X") },
	{ 0xe410, CFSTR("X.x") },
	{ 0xe410, CFSTR("x.X") },
	{ 0xe417, CFSTR(":*") },
	{ 0xe417, CFSTR(":-*") },
	{ 0xe417, CFSTR("=*") },
	{ 0xe417, CFSTR("=-*") },
	{ 0xe418, CFSTR(";*") },
	{ 0xe418, CFSTR(";-*") },
	{ 0xe401, CFSTR(":'(") },
	{ 0xe401, CFSTR("='(") },
	{ 0xe404, CFSTR(":!") },
	{ 0xe404, CFSTR(":-!") },
	{ 0xe404, CFSTR("=!") },
	{ 0xe404, CFSTR("=-!") },
	{ 0xe40c, CFSTR(":&") },
	{ 0xe40c, CFSTR(":-&") },
	{ 0xe40c, CFSTR("=&") },
	{ 0xe40c, CFSTR("=-&") },
	{ 0xe40c, CFSTR(":#") },
	{ 0xe40c, CFSTR(":-#") },
	{ 0xe40c, CFSTR("=#") },
	{ 0xe40c, CFSTR("=-#") },
	{ 0xe411, CFSTR(":\"o") },
	{ 0xe411, CFSTR("=\"o") },
	{ 0xe411, CFSTR(":\"O") },
	{ 0xe411, CFSTR("=\"O") },
	{ 0xe412, CFSTR(":'D") },
	{ 0xe412, CFSTR("='D") },
	{ 0xe413, CFSTR(";(") },
	{ 0xe408, CFSTR(";'(") },
	{ 0xe40f, CFSTR(":'o") },
	{ 0xe40f, CFSTR(":'O") },
	{ 0xe40f, CFSTR("='o") },
	{ 0xe40f, CFSTR("='O") },
	{ 0xe40e, CFSTR(":-/") },
	{ 0xe40e, CFSTR(":-\\") },
	{ 0xe40e, CFSTR("=-/") },
	{ 0xe40e, CFSTR("=-\\") },
	{ 0xe40b, CFSTR(":-o") },
	{ 0xe107, CFSTR(":-O") },
	{ 0xe40b, CFSTR("=-o") },
	{ 0xe107, CFSTR("=-O") },
	{ 0xe402, CFSTR(":j") },
	{ 0xe402, CFSTR(":-j") },
	{ 0xe402, CFSTR("=j") },
	{ 0xe402, CFSTR("=-j") },
	{ 0xe40a, CFSTR(":>") },
	{ 0xe40a, CFSTR(":->") },
	{ 0xe40a, CFSTR("=>") },
	{ 0xe40a, CFSTR("=->") },
	{ 0xe416, CFSTR("}:(") },
	{ 0xe416, CFSTR("}:-(") },
	{ 0xe416, CFSTR("}=(") },
	{ 0xe416, CFSTR("}=-(") },
	{ 0xe059, CFSTR(">:-(") },
	{ 0xe11a, CFSTR(">:-)") },
	{ 0xe059, CFSTR(">=-(") },
	{ 0xe11a, CFSTR(">=-)") },
	{ 0xe04e, CFSTR("O:-)") },
	{ 0xe04e, CFSTR("o:-)") },

// Rare
	{ 0xe05a, CFSTR("~<:)") },
	{ 0xe048, CFSTR(":^)") },
	{ 0xe048, CFSTR(";^)") },
	{ 0xe048, CFSTR("=^)") },
	{ 0xe032, CFSTR("@};-") },
	{ 0xe032, CFSTR("@>-") },
	{ 0xe032, CFSTR("-;{@") },
	{ 0xe032, CFSTR("-<@") },
	{ 0xe445, CFSTR("(~~)") },
	{ 0xe50c, CFSTR("**==") },
	{ 0xe00e, CFSTR("(Y)") },
	{ 0xe00e, CFSTR("(y)") },
	{ 0xe421, CFSTR("(N)") },
	{ 0xe421, CFSTR("(n)") },
	{ 0xe106, CFSTR("(<3") },
	{ 0xe409, CFSTR("d:") },
	{ 0xe409, CFSTR("d=") },
	{ 0xe409, CFSTR("d-:") },
	{ 0xe056, CFSTR("(-:") },
	{ 0xe056, CFSTR("(-=") },
	{ 0xe058, CFSTR(")-:") },
	{ 0xe058, CFSTR(")-=") },
	{ 0xe058, CFSTR("]-:") },
	{ 0xe058, CFSTR("]-=") },
	{ 0xe401, CFSTR(")':") },
	{ 0xe401, CFSTR(")'=") },
	{ 0xe404, CFSTR("!:") },
	{ 0xe404, CFSTR("!-:") },
	{ 0xe404, CFSTR("!-=") },
	{ 0xe40b, CFSTR("o:") },
	{ 0xe107, CFSTR("O:") },
	{ 0xe40b, CFSTR("o-:") },
	{ 0xe107, CFSTR("O-:") },
	{ 0xe40b, CFSTR("o=") },
	{ 0xe107, CFSTR("O=") },
	{ 0xe40b, CFSTR("o-=") },
	{ 0xe107, CFSTR("O-=") },
	{ 0xe107, CFSTR("0:") },
	{ 0xe107, CFSTR("0-:") },
	{ 0xe107, CFSTR("0=") },
	{ 0xe107, CFSTR("0-=") },
	{ 0xe418, CFSTR("*;") },
	{ 0xe418, CFSTR("*-;") },
	{ 0xe417, CFSTR("*:") },
	{ 0xe417, CFSTR("*-:") },
	{ 0xe417, CFSTR("*=") },
	{ 0xe417, CFSTR("*-=") },
	{ 0xe11a, CFSTR("(:<") },
	{ 0xe059, CFSTR("):<") },
	{ 0xe11a, CFSTR("(-:<") },
	{ 0xe059, CFSTR(")-:<") },
	{ 0xe11a, CFSTR("(=<") },
	{ 0xe059, CFSTR(")=<") },
	{ 0xe11a, CFSTR("(-=<") },
	{ 0xe059, CFSTR(")-=<") },
	{ 0xe04e, CFSTR("(:O") },
	{ 0xe04e, CFSTR("(:o") },
	{ 0xe04e, CFSTR("(-:O") },
	{ 0xe04e, CFSTR("(-:o") },
	{ 0xe04e, CFSTR("(=O") },
	{ 0xe04e, CFSTR("(=o") },
	{ 0xe04e, CFSTR("(-=O") },
	{ 0xe04e, CFSTR("(-=o") },

	{ 0, nil }
};

BOOL isValidUTF8( const char *s, NSUInteger len ) {
	BOOL only7bit = YES;

	for( NSUInteger i = 0; i < len; ++i ) {
		const unsigned char ch = s[i];

		if( is7Bit( ch ) )
			continue;

		if( only7bit )
			only7bit = NO;

		if( isUTF8Tupel( ch ) ) {
			if( len - i < 1 ) // too short
				return NO;
			if( isUTF8LongTupel( ch ) ) // not minimally encoded
				return NO;
			if( ! isUTF8Cont( s[i + 1] ) )
				return NO;
			i += 1;
		} else if( isUTF8Triple( ch ) ) {
			if( len - i < 2 ) // too short
				return NO;
			if( isUTF8LongTriple( ch, s[i + 1] ) ) // not minimally encoded
				return NO;
			if( ! isUTF8Cont( s[i + 1] ) || ! isUTF8Cont( s[i + 2] ) )
				return NO;
			i += 2;
		} else if( isUTF8Quartet( ch ) ) {
			if( len - i < 3 ) // too short
				return NO;
			if( isUTF8LongQuartet( ch, s[i + 1] ) ) // not minimally encoded
				return NO;
			if( ! isUTF8Cont( s[i + 1] ) || ! isUTF8Cont( s[i + 2] ) || ! isUTF8Cont( s[i + 3] ) )
				return NO;
			i += 3;
		} else if( isUTF8Quintet( ch ) ) {
			if( len - i < 4 ) // too short
				return NO;
			if( isUTF8LongQuintet( ch, s[i + 1] ) ) // not minimally encoded
				return NO;
			if( ! isUTF8Cont( s[i + 1] ) || ! isUTF8Cont( s[i + 2] ) || ! isUTF8Cont( s[i + 3] ) || ! isUTF8Cont( s[i + 4] ) )
				return NO;
			i += 4;
		} else if( isUTF8Sextet( ch ) ) {
			if( len - i < 5 ) // too short
				return NO;
			if( isUTF8LongSextet( ch, s[i + 1] ) ) // not minimally encoded
				return NO;
			if( ! isUTF8Cont( s[i + 1] ) || ! isUTF8Cont( s[i + 2] ) || ! isUTF8Cont( s[i + 3] ) || ! isUTF8Cont( s[i + 4] ) || ! isUTF8Cont( s[i + 5] ) )
				return NO;
			i += 5;
		} else return NO;
	}

	if( only7bit )
		return NO; // technically it can be UTF8, but it might be another 7-bit encoding
	return YES;
}

static const unsigned char mIRCColors[][3] = {
	{ 0xff, 0xff, 0xff }, /* 00) white */
	{ 0x00, 0x00, 0x00 }, /* 01) black */
	{ 0x00, 0x00, 0x7b }, /* 02) blue */
	{ 0x00, 0x94, 0x00 }, /* 03) green */
	{ 0xff, 0x00, 0x00 }, /* 04) red */
	{ 0x7b, 0x00, 0x00 }, /* 05) brown */
	{ 0x9c, 0x00, 0x9c }, /* 06) purple */
	{ 0xff, 0x7b, 0x00 }, /* 07) orange */
	{ 0xff, 0xff, 0x00 }, /* 08) yellow */
	{ 0x00, 0xff, 0x00 }, /* 09) bright green */
	{ 0x00, 0x94, 0x94 }, /* 10) cyan */
	{ 0x00, 0xff, 0xff }, /* 11) bright cyan */
	{ 0x00, 0x00, 0xff }, /* 12) bright blue */
	{ 0xff, 0x00, 0xff }, /* 13) bright purple */
	{ 0x7b, 0x7b, 0x7b }, /* 14) gray */
	{ 0xd6, 0xd6, 0xd6 } /* 15) light gray */
};

static const unsigned char CTCPColors[][3] = {
	{ 0x00, 0x00, 0x00 }, /* 0) black */
	{ 0x00, 0x00, 0x7f }, /* 1) blue */
	{ 0x00, 0x7f, 0x00 }, /* 2) green */
	{ 0x00, 0x7f, 0x7f }, /* 3) cyan */
	{ 0x7f, 0x00, 0x00 }, /* 4) red */
	{ 0x7f, 0x00, 0x7f }, /* 5) purple */
	{ 0x7f, 0x7f, 0x00 }, /* 6) brown */
	{ 0xc0, 0xc0, 0xc0 }, /* 7) light gray */
	{ 0x7f, 0x7f, 0x7f }, /* 8) gray */
	{ 0x00, 0x00, 0xff }, /* 9) bright blue */
	{ 0x00, 0xff, 0x00 }, /* A) bright green */
	{ 0x00, 0xff, 0xff }, /* B) bright cyan */
	{ 0xff, 0x00, 0x00 }, /* C) bright red */
	{ 0xff, 0x00, 0xff }, /* D) bright magenta */
	{ 0xff, 0xff, 0x00 }, /* E) yellow */
	{ 0xff, 0xff, 0xff } /* F) white */
};

static BOOL scanOneOrTwoDigits( NSScanner *scanner, NSUInteger *number ) {
	NSCharacterSet *characterSet = [NSCharacterSet decimalDigitCharacterSet];
	NSString *chars = nil;

	if( ! [scanner scanCharactersFromSet:characterSet maxLength:2 intoString:&chars] )
		return NO;

	*number = [chars intValue];
	return YES;
}

static NSString *colorForHTML( unsigned char red, unsigned char green, unsigned char blue ) {
	return [NSString stringWithFormat:@"#%02X%02X%02X", red, green, blue];
}

@implementation NSString (NSStringAdditions)
+ (NSString *) locallyUniqueString {
    // TODO: Consider replace calls to this method with NSUUID
	struct timeval tv;
	gettimeofday( &tv, NULL );

	NSUInteger m = 36; // base (denominator)
	NSUInteger q = [[NSProcessInfo processInfo] processIdentifier] ^ tv.tv_usec; // input (quotient)
	NSUInteger r = 0; // remainder

	NSMutableString *uniqueId = [[NSMutableString alloc] initWithCapacity:10];
	[uniqueId appendFormat:@"%c", (char)('A' + ( arc4random() % 26 ))]; // always have a random letter first (more ambiguity)

	#define baseConvert	do { \
		r = q % m; \
		q = q / m; \
		if( r >= 10 ) r = 'A' + ( r - 10 ); \
		else r = '0' + r; \
		[uniqueId appendFormat:@"%c", (char)r]; \
	} while( q ) \

	baseConvert;

	q = ( tv.tv_sec - 1104555600 ); // subtract 35 years, we only care about post Jan 1 2005

	baseConvert;

	#undef baseConvert

	return uniqueId;
}

#if ENABLE(SCRIPTING)
+ (OSType) scriptTypedEncodingFromStringEncoding:(NSStringEncoding) encoding {
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

+ (NSStringEncoding) stringEncodingFromScriptTypedEncoding:(OSType) encoding {
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
#endif

#pragma mark -

+ (NSArray <NSString *> *) knownEmoticons {
	static NSMutableArray <NSString *> *knownEmoticons;
	if( ! knownEmoticons ) {
		knownEmoticons = [[NSMutableArray alloc] initWithCapacity:350];
		for (const struct EmojiEmoticonPair *entry = emoticonToEmojiList; entry && entry->emoticon; ++entry)
			[knownEmoticons addObject:(__bridge id)entry->emoticon];
	}

	return knownEmoticons;
}

+ (NSSet *) knownEmojiWithEmoticons {
	static NSMutableSet *knownEmoji;
	if( ! knownEmoji ) {
		knownEmoji = [[NSMutableSet alloc] initWithCapacity:50];
		for (const struct EmojiEmoticonPair *entry = emojiToEmoticonList; entry && entry->emoticon; ++entry) {
			NSString *emojiString = [[NSString alloc] initWithCharacters:&entry->emoji length:1];
			[knownEmoji addObject:emojiString];
		}
	}

	return knownEmoji;
}

#pragma mark -

- (instancetype) initWithChatData:(NSData *) data encoding:(NSStringEncoding) encoding {
	if( ! encoding ) encoding = NSISOLatin1StringEncoding;

	// Search for CTCP/2 encoding tags and act on them
	NSMutableData *newData = [NSMutableData dataWithCapacity:data.length];
	NSStringEncoding currentEncoding = encoding;

	const char *bytes = [data bytes];
	NSUInteger length = data.length;
	NSUInteger j = 0, start = 0, end = 0;
	for( NSUInteger i = 0; i < length; i++ ) {
		if( bytes[i] == '\006' ) {
			end = i;
			j = ++i;

			for( ; i < length && bytes[i] != '\006'; i++ );
			if( i >= length ) break;
			if( i == j ) continue;

			if( bytes[j++] == 'E' ) {
				NSString *encodingStr = [[NSString alloc] initWithBytes:( bytes + j ) length:( i - j ) encoding:NSASCIIStringEncoding];
				NSStringEncoding newEncoding = 0;
				if( ! encodingStr.length ) { // if no encoding is declared, go back to user default
					newEncoding = encoding;
				} else if( [encodingStr isEqualToString:@"U"] ) {
					newEncoding = NSUTF8StringEncoding;
				} else {
					NSUInteger enc = [encodingStr intValue];
					switch( enc ) {
						case 1:
							newEncoding = NSISOLatin1StringEncoding;
							break;
						case 2:
							newEncoding = NSISOLatin2StringEncoding;
							break;
						case 3:
							newEncoding = CFStringConvertEncodingToNSStringEncoding( kCFStringEncodingISOLatin3 );
							break;
						case 4:
							newEncoding = CFStringConvertEncodingToNSStringEncoding( kCFStringEncodingISOLatin4 );
							break;
						case 5:
							newEncoding = CFStringConvertEncodingToNSStringEncoding( kCFStringEncodingISOLatinCyrillic );
							break;
						case 6:
							newEncoding = CFStringConvertEncodingToNSStringEncoding( kCFStringEncodingISOLatinArabic );
							break;
						case 7:
							newEncoding = CFStringConvertEncodingToNSStringEncoding( kCFStringEncodingISOLatinGreek );
							break;
						case 8:
							newEncoding = CFStringConvertEncodingToNSStringEncoding( kCFStringEncodingISOLatinHebrew );
							break;
						case 9:
							newEncoding = CFStringConvertEncodingToNSStringEncoding( kCFStringEncodingISOLatin5 );
							break;
						case 10:
							newEncoding = CFStringConvertEncodingToNSStringEncoding( kCFStringEncodingISOLatin6 );
							break;
					}
				}

				if( newEncoding && newEncoding != currentEncoding ) {
					if( ( end - start ) > 0 ) {
						NSData *subData = nil;
						if( currentEncoding != NSUTF8StringEncoding ) {
							NSString *tempStr = [[NSString alloc] initWithBytes:( bytes + start ) length:( end - start ) encoding:currentEncoding];
							NSData *utf8Data = [tempStr dataUsingEncoding:NSUTF8StringEncoding];
							if( utf8Data ) subData = utf8Data;
						} else {
							subData = [[NSData alloc] initWithBytesNoCopy:(void *)( bytes + start ) length:( end - start ) freeWhenDone:NO];
						}

						if( subData ) [newData appendData:subData];
					}

					currentEncoding = newEncoding;
					start = i + 1;
				}
			}
		}
	}

	if( newData.length > 0 || currentEncoding != encoding ) {
		if( start < length ) {
			NSData *subData = nil;
			if( currentEncoding != NSUTF8StringEncoding ) {
				NSString *tempStr = [[NSString alloc] initWithBytes:( bytes + start ) length:( length - start ) encoding:currentEncoding];
				NSData *utf8Data = [tempStr dataUsingEncoding:NSUTF8StringEncoding];
				if( utf8Data ) subData = utf8Data;
			} else {
				subData = [[NSData alloc] initWithBytesNoCopy:(void *)( bytes + start ) length:( length - start ) freeWhenDone:NO];
			}

			if( subData ) [newData appendData:subData];
		}

		encoding = NSUTF8StringEncoding;
		data = newData;
	}

	if( encoding != NSUTF8StringEncoding && isValidUTF8( [data bytes], data.length ) )
		encoding = NSUTF8StringEncoding;

	NSString *message = [[NSString alloc] initWithData:data encoding:encoding];
	if( ! message ) {
		return nil;
	}

	NSCharacterSet *formatCharacters = [NSCharacterSet characterSetWithCharactersInString:@"\002\003\006\026\037\017"];

	// if the message dosen't have any formatting chars just init as a plain string and return quickly
	if( [message rangeOfCharacterFromSet:formatCharacters].location == NSNotFound ) {
		self = [self initWithString:[message stringByEncodingXMLSpecialCharactersAsEntities]];
		return self;
	}

	NSMutableString *ret = [NSMutableString string];
	NSScanner *scanner = [NSScanner scannerWithString:message];
	[scanner setCharactersToBeSkipped:nil]; // don't skip leading whitespace!

	NSUInteger boldStack = 0, italicStack = 0, underlineStack = 0, strikeStack = 0, colorStack = 0;

	while( ! [scanner isAtEnd] ) {
		NSString *cStr = nil;
		if( [scanner scanCharactersFromSet:formatCharacters maxLength:1 intoString:&cStr] ) {
			unichar c = [cStr characterAtIndex:0];
			switch( c ) {
			case '\017': // reset all
				if( boldStack )
					[ret appendString:@"</b>"];
				if( italicStack )
					[ret appendString:@"</i>"];
				if( underlineStack )
					[ret appendString:@"</u>"];
				if( strikeStack )
					[ret appendString:@"</strike>"];
				for( NSUInteger i = 0; i < colorStack; ++i )
					[ret appendString:@"</span>"];

				boldStack = italicStack = underlineStack = strikeStack = colorStack = 0;
				break;
			case '\002': // toggle bold
				boldStack = ! boldStack;

				if( boldStack ) [ret appendString:@"<b>"];
				else [ret appendString:@"</b>"];
				break;
			case '\026': // toggle italic
				italicStack = ! italicStack;

				if( italicStack ) [ret appendString:@"<i>"];
				else [ret appendString:@"</i>"];
				break;
			case '\037': // toggle underline
				underlineStack = ! underlineStack;

				if( underlineStack ) [ret appendString:@"<u>"];
				else [ret appendString:@"</u>"];
				break;
			case '\003': // color
			{
				NSUInteger fcolor = 0;
				if( scanOneOrTwoDigits( scanner, &fcolor ) ) {
					fcolor %= 16;

					NSString *foregroundColor = colorForHTML(mIRCColors[fcolor][0], mIRCColors[fcolor][1], mIRCColors[fcolor][2]);
					[ret appendFormat:@"<span style=\"color: %@;", foregroundColor];

					NSUInteger bcolor = 0;
					if( [scanner scanString:@"," intoString:NULL] && scanOneOrTwoDigits( scanner, &bcolor ) && bcolor != 99 ) {
						bcolor %= 16;

						NSString *backgroundColor = colorForHTML(mIRCColors[bcolor][0], mIRCColors[bcolor][1], mIRCColors[bcolor][2]);
						[ret appendFormat:@" background-color: %@;", backgroundColor];
					}

					[ret appendString:@"\">"];

					++colorStack;
				} else { // no color, reset both colors
					for( NSUInteger i = 0; i < colorStack; ++i )
						[ret appendString:@"</span>"];
					colorStack = 0;
				}
				break;
			}
			case '\006': // ctcp 2 formatting (http://www.lag.net/~robey/ctcp/ctcp2.2.txt)
				if( ! [scanner isAtEnd] ) {
					BOOL off = NO;

					unichar formatChar = [message characterAtIndex:[scanner scanLocation]];
					[scanner setScanLocation:[scanner scanLocation]+1];

					switch( formatChar ) {
					case 'B': // bold
						if( [scanner scanString:@"-" intoString:NULL] ) {
							if( boldStack >= 1 ) boldStack--;
							off = YES;
						} else { // on is the default
							[scanner scanString:@"+" intoString:NULL];
							boldStack++;
						}

						if( boldStack == 1 && ! off )
							[ret appendString:@"<b>"];
						else if( ! boldStack )
							[ret appendString:@"</b>"];
						break;
					case 'I': // italic
						if( [scanner scanString:@"-" intoString:NULL] ) {
							if( italicStack >= 1 ) italicStack--;
							off = YES;
						} else { // on is the default
							[scanner scanString:@"+" intoString:NULL];
							italicStack++;
						}

						if( italicStack == 1 && ! off )
							[ret appendString:@"<i>"];
						else if( ! italicStack )
							[ret appendString:@"</i>"];
						break;
					case 'U': // underline
						if( [scanner scanString:@"-" intoString:NULL] ) {
							if( underlineStack >= 1 ) underlineStack--;
							off = YES;
						} else { // on is the default
							[scanner scanString:@"+" intoString:NULL];
							underlineStack++;
						}

						if( underlineStack == 1 && ! off )
							[ret appendString:@"<u>"];
						else if( ! underlineStack )
							[ret appendString:@"</u>"];
						break;
					case 'S': // strikethrough
						if( [scanner scanString:@"-" intoString:NULL] ) {
							if( strikeStack >= 1 ) strikeStack--;
							off = YES;
						} else { // on is the default
							[scanner scanString:@"+" intoString:NULL];
							strikeStack++;
						}

						if( strikeStack == 1 && ! off )
							[ret appendString:@"<strike>"];
						else if( ! strikeStack )
							[ret appendString:@"</strike>"];
						break;
					case 'C': { // color
						if( [message characterAtIndex:[scanner scanLocation]] == '\006' ) { // reset colors
							for( NSUInteger i = 0; i < colorStack; ++i )
								[ret appendString:@"</span>"];
							colorStack = 0;
							break;
						}

						// scan for foreground color
						NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"];
						NSString *colorStr = nil;
						BOOL foundForeground = YES;
						if( [scanner scanString:@"#" intoString:NULL] ) { // rgb hex color
							if( [scanner scanCharactersFromSet:hexSet maxLength:6 intoString:&colorStr] ) {
								[ret appendFormat:@"<span style=\"color: %@;", colorStr];
							} else foundForeground = NO;
						} else if( [scanner scanCharactersFromSet:hexSet maxLength:1 intoString:&colorStr] ) { // indexed color
							NSUInteger index = [colorStr characterAtIndex:0];
							if( index >= 'A' ) index -= ( 'A' - '9' - 1 );
							index -= '0';

							NSString *foregroundColor = colorForHTML(CTCPColors[index][0], CTCPColors[index][1], CTCPColors[index][2]);
							[ret appendFormat:@"<span style=\"color: %@;", foregroundColor];
						} else if( [scanner scanString:@"." intoString:NULL] ) { // reset the foreground color
							[ret appendString:@"<span style=\"color: initial;"];
						} else if( [scanner scanString:@"-" intoString:NULL] ) { // skip the foreground color
							// Do nothing - we're skipping
							// This is so we can have an else clause that doesn't fire for @"-"
						} else {
							// Ok, no foreground color
							foundForeground = NO;
						}

						if( foundForeground ) {
							// scan for background color
							if( [scanner scanString:@"#" intoString:NULL] ) { // rgb hex color
								if( [scanner scanCharactersFromSet:hexSet maxLength:6 intoString:&colorStr] )
									[ret appendFormat:@" background-color: %@;", colorStr];
							} else if( [scanner scanCharactersFromSet:hexSet maxLength:1 intoString:&colorStr] ) { // indexed color
								NSUInteger index = [colorStr characterAtIndex:0];
								if( index >= 'A' ) index -= ( 'A' - '9' - 1 );
								index -= '0';

								NSString *backgroundColor = colorForHTML(CTCPColors[index][0], CTCPColors[index][1], CTCPColors[index][2]);
								[ret appendFormat:@" background-color: %@;", backgroundColor];
							} else if( [scanner scanString:@"." intoString:NULL] ) { // reset the background color
								[ret appendString:@" background-color: initial;"];
							} else [scanner scanString:@"-" intoString:NULL]; // skip the background color

							[ret appendString:@"\">"];

							++colorStack;
						} else {
							// No colors - treat it like ..
							for( NSUInteger i = 0; i < colorStack; ++i )
								[ret appendString:@"</span>"];
							colorStack = 0;
						}
					} case 'F': // font size
					case 'E': // encoding
						// We actually handle this above, but there could be some encoding tags
						// left over. For instance, ^FEU^F^FEU^F will leave one of the two tags behind.
					case 'K': // blinking
					case 'P': // spacing
						// not supported yet
						break;
					case 'N': // normal (reset)
						if( boldStack )
							[ret appendString:@"</b>"];
						if( italicStack )
							[ret appendString:@"</i>"];
						if( underlineStack )
							[ret appendString:@"</u>"];
						if( strikeStack )
							[ret appendString:@"</strike>"];
						for( NSUInteger i = 0; i < colorStack; ++i )
							[ret appendString:@"</span>"];

						boldStack = italicStack = underlineStack = strikeStack = colorStack = 0;
					}

					[scanner scanUpToString:@"\006" intoString:NULL];
					[scanner scanString:@"\006" intoString:NULL];
				}
			}
		}

		NSString *text = nil;
 		[scanner scanUpToCharactersFromSet:formatCharacters intoString:&text];

		if( text.length )
			[ret appendString:[text stringByEncodingXMLSpecialCharactersAsEntities]];
	}

	return [self initWithString:ret];
}

#pragma mark -

- (BOOL) isCaseInsensitiveEqualToString:(NSString *) string {
	return [self compare:string options:NSCaseInsensitiveSearch range:NSMakeRange( 0, self.length )] == NSOrderedSame;
}

- (BOOL) hasCaseInsensitivePrefix:(NSString *) prefix {
	return [self rangeOfString:prefix options:( NSCaseInsensitiveSearch | NSAnchoredSearch ) range:NSMakeRange( 0, self.length )].location != NSNotFound;
}

- (BOOL) hasCaseInsensitiveSuffix:(NSString *) suffix {
	return [self rangeOfString:suffix options:( NSCaseInsensitiveSearch | NSBackwardsSearch | NSAnchoredSearch ) range:NSMakeRange( 0, self.length )].location != NSNotFound;
}

- (BOOL) hasCaseInsensitiveSubstring:(NSString *) substring {
	return [self rangeOfString:substring options:NSCaseInsensitiveSearch range:NSMakeRange( 0, self.length )].location != NSNotFound;
}

#pragma mark -

- (NSString *) cq_sentenceCaseString {
	NSMutableString *copy = [self mutableCopy];
	[copy enumerateSubstringsInRange:NSMakeRange(0, copy.length) options:NSStringEnumerationBySentences usingBlock:^(NSString *sentence, NSRange sentenceRange, NSRange enclosingRange, BOOL *stop) {
		const NSLinguisticTaggerOptions options = NSLinguisticTaggerOmitPunctuation | NSLinguisticTaggerOmitWhitespace | NSLinguisticTaggerOmitOther | NSLinguisticTaggerJoinNames;
		[copy enumerateLinguisticTagsInRange:sentenceRange scheme:NSLinguisticTagSchemeTokenType options:options orthography:nil usingBlock:^(NSString *tag, NSRange tokenRange, NSRange tokenSentenceRange, BOOL *innerStop) {
			[copy replaceCharactersInRange:tokenRange withString:[[copy substringWithRange:tokenRange] capitalizedStringWithLocale:[NSLocale currentLocale]]];
			*innerStop = YES;
		}];
	}];
	return [copy copy];
}

+ (NSString *) cq_stringByReversingString:(NSString *) normalString {
	NSMutableString *reversedString = [[NSMutableString alloc] initWithCapacity:normalString.length];

	for (NSInteger index = normalString.length - 1; index >= 0; index--)
		[reversedString appendString:[normalString substringWithRange:NSMakeRange(index, 1)]];

	return reversedString;
}

#pragma mark -

- (NSString *) stringByEncodingXMLSpecialCharactersAsEntities {
	NSRange range = [self rangeOfCharacterFromSet:[NSCharacterSet cq_encodedXMLCharacterSet] options:NSLiteralSearch];
	if( range.location == NSNotFound )
		return self;

	NSMutableString *result = [self mutableCopy];
	[result encodeXMLSpecialCharactersAsEntities];
	return result;
}

- (NSString *) stringByDecodingXMLSpecialCharacterEntities {
	NSRange range = [self rangeOfString:@"&" options:NSLiteralSearch];
	if( range.location == NSNotFound )
		return self;

	NSMutableString *result = [self mutableCopy];
	[result decodeXMLSpecialCharacterEntities];
	return result;
}

#pragma mark -

- (NSString *) stringByEscapingCharactersInSet:(NSCharacterSet *) set {
	NSRange range = [self rangeOfCharacterFromSet:set];
	if( range.location == NSNotFound )
		return self;

	NSMutableString *result = [self mutableCopy];
	[result escapeCharactersInSet:set];
	return result;
}

- (NSString *) stringByReplacingCharactersInSet:(NSCharacterSet *) set withString:(NSString *) string {
	NSRange range = [self rangeOfCharacterFromSet:set];
	if( range.location == NSNotFound )
		return self;

	NSMutableString *result = [self mutableCopy];
	[result replaceCharactersInSet:set withString:string];
	return result;
}

#pragma mark -

- (NSString *__nullable) stringByEncodingIllegalURLCharacters {
	static NSCharacterSet *illegalURLCharacters = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		illegalURLCharacters = [NSCharacterSet characterSetWithCharactersInString:@",;:/?@&$=|^~`\{}[]"];
	});
	return [self stringByAddingPercentEncodingWithAllowedCharacters:illegalURLCharacters];
}

- (NSString *__nullable) stringByDecodingIllegalURLCharacters {
	return [self stringByRemovingPercentEncoding];
}

#pragma mark -

- (NSString *) stringByStrippingIllegalXMLCharacters {
	NSRange range = [self rangeOfCharacterFromSet:[NSCharacterSet illegalXMLCharacterSet]];

	if( range.location == NSNotFound )
		return self;

	NSMutableString *result = [self mutableCopy];
	[result stripIllegalXMLCharacters];
	return result;
}

- (NSString *) stringByStrippingXMLTags {
	if( [self rangeOfString:@"<"].location == NSNotFound )
		return self;

	NSMutableString *result = [self mutableCopy];
	[result stripXMLTags];
	return result;
}

#pragma mark -

- (NSString *) stringWithDomainNameSegmentOfAddress {
	NSString *ret = self;
	unsigned ip = 0;
	BOOL ipAddress = ( sscanf( [self UTF8String], "%u.%u.%u.%u", &ip, &ip, &ip, &ip ) == 4 );

	if( ! ipAddress ) {
		NSArray <NSString *> *parts = [self componentsSeparatedByString:@"."];
		NSUInteger count = parts.count;
		if( count > 2 )
			ret = [NSString stringWithFormat:@"%@.%@", parts[(count - 2)], parts[(count - 1)]];
	}

	return ret;
}

#pragma mark -

- (NSString *) fileName {
	NSString *fileName = [self lastPathComponent];
	NSString *fileExtension = [NSString stringWithFormat:@".%@", [self pathExtension]];

	return [fileName stringByReplacingOccurrencesOfString:fileExtension withString:@""];
}

#pragma mark -

- (NSArray <NSString *> * __nullable) _IRCComponents {
	NSArray <NSString *> *components = [self componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"!@ "]];

	// given "nickname!username@hostmask realname", we want to get "nickname", "username", "hostmask" and "realname" back
	if (components.count == 3 || components.count == 4)
		return components;
	return nil;
}

- (BOOL) isValidIRCMask {
	// if we have a nickname matched, we have a valid IRC mask
	return self.IRCNickname.length;
}

- (NSString *__nullable) IRCNickname {
	return self._IRCComponents[0];
}

- (NSString *__nullable) IRCUsername {
	return self._IRCComponents[1];
}

- (NSString *__nullable) IRCHostname {
	return self._IRCComponents[2];
}

- (NSString *__nullable) IRCRealname {
	NSArray <NSString *> *components = self._IRCComponents;
	if (components.count == 4)
		return components[3];
	return nil;
}

#pragma mark -

static NSCharacterSet *emojiCharacters;
static NSCharacterSet *typicalEmoticonCharacters;

- (BOOL) containsEmojiCharacters {
	return [self containsEmojiCharactersInRange:NSMakeRange(0, self.length)];
}

- (BOOL) containsEmojiCharactersInRange:(NSRange) range {
	return ([self rangeOfEmojiCharactersInRange:range].location != NSNotFound);
}

- (NSRange) rangeOfEmojiCharactersInRange:(NSRange) range {
	if (!emojiCharacters)
		emojiCharacters = [NSCharacterSet characterSetWithRange:NSMakeRange(0xe001, (0xe53e - 0xe001))];
	return [self rangeOfCharacterFromSet:emojiCharacters options:NSLiteralSearch range:range];
}

- (BOOL) containsTypicalEmoticonCharacters {
	if (!typicalEmoticonCharacters)
		typicalEmoticonCharacters = [NSCharacterSet characterSetWithCharactersInString:@";:=-()^><_."];
	return ([self rangeOfCharacterFromSet:typicalEmoticonCharacters options:NSLiteralSearch].location != NSNotFound || [self hasCaseInsensitiveSubstring:@"XD"]);
}

- (NSString *) stringBySubstitutingEmojiForEmoticons {
	if (![self containsEmojiCharacters])
		return self;
	NSMutableString *result = [self mutableCopy];
	[result substituteEmojiForEmoticons];
	return result;
}

- (NSString *) stringBySubstitutingEmoticonsForEmoji {
	if (![self containsTypicalEmoticonCharacters])
		return self;
	NSMutableString *result = [self mutableCopy];
	[result substituteEmoticonsForEmoji];
	return result;
}

#pragma mark -

- (BOOL) isMatchedByRegex:(NSString *) regex {
	return [self isMatchedByRegex:regex options:0 inRange:NSMakeRange(0, self.length) error:nil];
}

- (BOOL) isMatchedByRegex:(NSString *) regex options:(NSRegularExpressionOptions) options inRange:(NSRange) range error:(NSError **) error {
	NSRegularExpression *regularExpression = [NSRegularExpression cachedRegularExpressionWithPattern:regex options:options error:error];
	NSRange foundRange = [regularExpression rangeOfFirstMatchInString:self options:NSMatchingReportCompletion range:range];
	return foundRange.location != NSNotFound;
}

- (NSRange) rangeOfRegex:(NSString *) regex inRange:(NSRange) range {
	return [self rangeOfRegex:regex options:0 inRange:range capture:0 error:nil];
}

- (NSRange) rangeOfRegex:(NSString *) regex options:(NSRegularExpressionOptions) options inRange:(NSRange) range capture:(NSInteger) capture error:(NSError **) error {
	NSRegularExpression *regularExpression = [NSRegularExpression cachedRegularExpressionWithPattern:regex options:options error:error];	
	NSTextCheckingResult *result = [regularExpression firstMatchInString:self options:NSMatchingReportCompletion range:range];

	if (result == nil)
		return NSMakeRange(NSNotFound, 0);

	NSRange foundRange = [result rangeAtIndex:capture];

	return foundRange;
}

- (NSString *__nullable) stringByMatching:(NSString *) regex capture:(NSInteger) capture {
	return [self stringByMatching:regex options:0 inRange:NSMakeRange(0, self.length) capture:capture error:nil];
}

- (NSString *__nullable) stringByMatching:(NSString *) regex options:(NSRegularExpressionOptions) options inRange:(NSRange) range capture:(NSInteger) capture error:(NSError **) error {
	NSRegularExpression *regularExpression = [NSRegularExpression cachedRegularExpressionWithPattern:regex options:options error:error];
	NSTextCheckingResult *result = [regularExpression firstMatchInString:self options:NSMatchingReportCompletion range:range];

	if (result == nil)
		return nil;

	NSRange resultRange = [result rangeAtIndex:capture];

	if (resultRange.location == NSNotFound)
		return nil;

	return [self substringWithRange:resultRange];
}

- (nullable NSArray <NSString *> *) captureComponentsMatchedByRegex:(NSString *) regex options:(NSRegularExpressionOptions) options range:(NSRange) range error:(NSError **) error {
	NSRegularExpression *regularExpression = [NSRegularExpression cachedRegularExpressionWithPattern:regex options:options error:error];
	NSTextCheckingResult *result = [regularExpression firstMatchInString:self options:NSMatchingReportCompletion range:range];

	if (result == nil)
		return @[];

	NSMutableArray <NSString *> *results = [NSMutableArray array];

	for (NSUInteger i = 1; i < (result.numberOfRanges - 1); i++)
		[results addObject:[self substringWithRange:[result rangeAtIndex:i]]];

	return [results copy];
}

- (nullable NSString *) stringByReplacingOccurrencesOfRegex:(NSString *) regex withString:(NSString *) replacement {
	return [self stringByReplacingOccurrencesOfRegex:regex withString:replacement options:0 range:NSMakeRange(0, self.length) error:nil];
}

- (nullable NSString *) stringByReplacingOccurrencesOfRegex:(NSString *) regex withString:(NSString *) replacement options:(NSRegularExpressionOptions) options range:(NSRange) searchRange error:(NSError **) error {
	NSMutableString *replacementString = [self mutableCopy];
	[replacementString replaceOccurrencesOfRegex:regex withString:replacement options:options range:searchRange error:error];
	return [replacementString copy];
}

#pragma mark -

- (NSString *) cq_stringByRemovingCharactersInSet:(NSCharacterSet *) set {
	NSMutableString *mutableStorage = [self mutableCopy];
	NSRange range = [mutableStorage rangeOfCharacterFromSet:set];
	while (range.location != NSNotFound) {
		[mutableStorage replaceCharactersInRange:range withString:@""];
		range = [mutableStorage rangeOfCharacterFromSet:set];
	}

	return [mutableStorage copy];
}
@end

#pragma mark -

@implementation NSMutableString (NSMutableStringAdditions)
- (void) encodeXMLSpecialCharactersAsEntities {
	NSRange range = [self rangeOfCharacterFromSet:[NSCharacterSet cq_encodedXMLCharacterSet] options:NSLiteralSearch];
	if( range.location == NSNotFound )
		return;

	NSUInteger length = self.length;
	for (NSUInteger i = 0; i < length; i++) {
		unichar character = [self characterAtIndex:i];
		switch (character) {
			case '&':
				[self replaceCharactersInRange:NSMakeRange(i, 1) withString:@"&amp;"];
				length += 4; i += 4;
				break;
			case '<':
				[self replaceCharactersInRange:NSMakeRange(i, 1) withString:@"&lt;"];
				length += 3; i += 3;
				break;
			case '>':
				[self replaceCharactersInRange:NSMakeRange(i, 1) withString:@"&gt;"];
				length += 3; i += 3;
				break;
			case '"':
				[self replaceCharactersInRange:NSMakeRange(i, 1) withString:@"&quot;"];
				length += 5; i += 5;
				break;
			case '\'':
				[self replaceCharactersInRange:NSMakeRange(i, 1) withString:@"&apos;"];
				length += 5; i += 5;
				break;
			default: break;
		}
	}
}

- (void) decodeXMLSpecialCharacterEntities {
	NSRange range = [self rangeOfString:@"&" options:NSLiteralSearch];
	if( range.location == NSNotFound )
		return;

	[self replaceOccurrencesOfString:@"&lt;" withString:@"<" options:NSLiteralSearch range:NSMakeRange( 0, self.length )];
	[self replaceOccurrencesOfString:@"&gt;" withString:@">" options:NSLiteralSearch range:NSMakeRange( 0, self.length )];
	[self replaceOccurrencesOfString:@"&quot;" withString:@"\"" options:NSLiteralSearch range:NSMakeRange( 0, self.length )];
	[self replaceOccurrencesOfString:@"&apos;" withString:@"'" options:NSLiteralSearch range:NSMakeRange( 0, self.length )];
	[self replaceOccurrencesOfString:@"&amp;" withString:@"&" options:NSLiteralSearch range:NSMakeRange( 0, self.length )];
}

#pragma mark -

- (void) escapeCharactersInSet:(NSCharacterSet *) set {
	NSRange range = [self rangeOfCharacterFromSet:set];
	if( range.location == NSNotFound )
		return;

	NSScanner *scanner = [[NSScanner alloc] initWithString:self];

	NSUInteger offset = 0;
	while( ! [scanner isAtEnd] ) {
		[scanner scanUpToCharactersFromSet:set intoString:nil];
		if( ! [scanner isAtEnd] ) {
			[self insertString:@"\\" atIndex:[scanner scanLocation] + offset++];
			[scanner setScanLocation:[scanner scanLocation] + 1];
		}
	}

}

- (void) replaceCharactersInSet:(NSCharacterSet *) set withString:(NSString *) string {
	NSRange range = NSMakeRange(0, self.length);
	NSUInteger stringLength = string.length;

	NSRange replaceRange;
	while( ( replaceRange = [self rangeOfCharacterFromSet:set options:NSLiteralSearch range:range] ).location != NSNotFound ) {
		[self replaceCharactersInRange:replaceRange withString:string];

		range.location = replaceRange.location + stringLength;
		range.length = self.length - replaceRange.location;
	}
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
	NSCharacterSet *illegalSet = [NSCharacterSet illegalXMLCharacterSet];
	NSRange range = [self rangeOfCharacterFromSet:illegalSet];
	while( range.location != NSNotFound ) {
		[self deleteCharactersInRange:range];
		range = [self rangeOfCharacterFromSet:illegalSet];
	}
}

- (void) stripXMLTags {
	NSRange searchRange = NSMakeRange(0, self.length);
	while (1) {
		NSRange tagStartRange = [self rangeOfString:@"<" options:NSLiteralSearch range:searchRange];
		if (tagStartRange.location == NSNotFound)
			break;

		NSRange tagEndRange = [self rangeOfString:@">" options:NSLiteralSearch range:NSMakeRange(tagStartRange.location, (self.length - tagStartRange.location))];
		if (tagEndRange.location == NSNotFound)
			break;

		[self deleteCharactersInRange:NSMakeRange(tagStartRange.location, (NSMaxRange(tagEndRange) - tagStartRange.location))];

		searchRange = NSMakeRange(tagStartRange.location, (self.length - tagStartRange.location));
	}
}

#pragma mark -

- (void) substituteEmoticonsForEmoji {
	NSRange range = NSMakeRange(0, self.length);
	[self substituteEmoticonsForEmojiInRange:&range];
}

- (void) substituteEmoticonsForEmojiInRange:(NSRangePointer) range {
	[self substituteEmoticonsForEmojiInRange:range withXMLSpecialCharactersEncodedAsEntities:NO];
}

- (void) substituteEmoticonsForEmojiInRange:(NSRangePointer) range withXMLSpecialCharactersEncodedAsEntities:(BOOL) encoded {
	if (![self containsTypicalEmoticonCharacters])
		return;

	static NSCharacterSet *escapedCharacters = nil;
	if (!escapedCharacters)
		escapedCharacters = [NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"];

	for (const struct EmojiEmoticonPair *entry = emoticonToEmojiList; entry && entry->emoticon; ++entry) {
		NSString *searchEmoticon = (__bridge id)entry->emoticon;
		if (encoded) searchEmoticon = [searchEmoticon stringByEncodingXMLSpecialCharactersAsEntities];
		if ([self rangeOfString:searchEmoticon options:NSLiteralSearch range:*range].location == NSNotFound)
			continue;

		NSMutableString *emoticon = [searchEmoticon mutableCopy];
		[emoticon escapeCharactersInSet:escapedCharacters];

		NSString *emojiString = [[NSString alloc] initWithCharacters:&entry->emoji length:1];
		NSString *searchRegex = [[NSString alloc] initWithFormat:@"(?<=\\s|^|[\ue001-\ue53e])%@(?=\\s|$|[\ue001-\ue53e])", emoticon];

		NSRange matchedRange = [self rangeOfRegex:searchRegex inRange:*range];
		while (matchedRange.location != NSNotFound) {
			[self replaceCharactersInRange:matchedRange withString:emojiString];
			range->length += (1 - matchedRange.length);

			NSRange matchRange = NSMakeRange(matchedRange.location + 1, (NSMaxRange(*range) - matchedRange.location - 1));
			if (!matchRange.length)
				break;

			matchedRange = [self rangeOfRegex:searchRegex inRange:matchRange];
		}

		// Check for the typical characters again, if none are found then there are no more emoticons to replace.
		if ([self rangeOfCharacterFromSet:typicalEmoticonCharacters].location == NSNotFound)
			break;
	}
}

- (void) substituteEmojiForEmoticons {
	NSRange range = NSMakeRange(0, self.length);
	[self substituteEmojiForEmoticonsInRange:&range encodeXMLSpecialCharactersAsEntities:NO];
}

- (void) substituteEmojiForEmoticonsInRange:(NSRangePointer) range {
	[self substituteEmojiForEmoticonsInRange:range encodeXMLSpecialCharactersAsEntities:NO];
}

- (void) substituteEmojiForEmoticonsInRange:(NSRangePointer) range encodeXMLSpecialCharactersAsEntities:(BOOL) encode {
	NSRange emojiRange = [self rangeOfEmojiCharactersInRange:*range];
	while (emojiRange.location != NSNotFound) {
		unichar currentCharacter = [self characterAtIndex:emojiRange.location];
		for (const struct EmojiEmoticonPair *entry = emojiToEmoticonList; entry && entry->emoji; ++entry) {
			if (entry->emoji == currentCharacter) {
				NSString *emoticon = (__bridge id)entry->emoticon;
				if (encode) emoticon = [emoticon stringByEncodingXMLSpecialCharactersAsEntities];

				NSString *replacement = nil;
				if (emojiRange.location == 0 && (emojiRange.location + 1) == self.length)
					replacement = emoticon;
				else if (emojiRange.location > 0 && (emojiRange.location + 1) == self.length && [self characterAtIndex:(emojiRange.location - 1)] == ' ')
					replacement = emoticon;
				else if ([self characterAtIndex:(emojiRange.location - 1)] == ' ' || ((emojiRange.location + 1) < self.length && [self characterAtIndex:(emojiRange.location + 1)] == ' '))
					replacement = emoticon;
				else if (emojiRange.location == 0 || [self characterAtIndex:(emojiRange.location - 1)] == ' ')
					replacement = [[NSString alloc] initWithFormat:@"%@ ", emoticon];
				else if ((emojiRange.location + 1) == self.length || [self characterAtIndex:(emojiRange.location + 1)] == ' ')
					replacement = [[NSString alloc] initWithFormat:@" %@", emoticon];
				else replacement = [[NSString alloc] initWithFormat:@" %@ ", emoticon];

				[self replaceCharactersInRange:NSMakeRange(emojiRange.location, 1) withString:replacement];

				range->length += (replacement.length - 1);

				break;
			}
		}

		if (emojiRange.location >= NSMaxRange(*range))
			return;

		emojiRange = [self rangeOfEmojiCharactersInRange:NSMakeRange(emojiRange.location + 1, (NSMaxRange(*range) - emojiRange.location - 1))];
	}
}

- (BOOL) replaceOccurrencesOfRegex:(NSString *) regex withString:(NSString *) replacement {
	return [self replaceOccurrencesOfRegex:regex withString:replacement options:0 range:NSMakeRange(0, self.length) error:nil];
}

- (BOOL) replaceOccurrencesOfRegex:(NSString *) regex withString:(NSString *) replacement options:(NSRegularExpressionOptions) options range:(NSRange) searchRange error:(NSError **) error {
	NSRegularExpression *regularExpression = [NSRegularExpression cachedRegularExpressionWithPattern:regex options:options error:error];
	if (!regularExpression)
		return NO;

	NSUInteger matches = [regularExpression replaceMatchesInString:self options:0 range:searchRange withTemplate:replacement];
	return matches > 0;
}
@end

NS_ASSUME_NONNULL_END
