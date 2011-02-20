#import "NSStringAdditions.h"

#import "NSCharacterSetAdditions.h"
#import "NSScannerAdditions.h"

#import "RegexKitLite.h"

#import <sys/time.h>

struct EmojiEmoticonPair {
	const unichar emoji;
	NSString *emoticon;
};

static const struct EmojiEmoticonPair emojiToEmoticonList[] = {
	{ 0xe00e, @"(Y)" },
	{ 0xe022, @"<3" },
	{ 0xe023, @"</3" },
	{ 0xe032, @"@};-" },
	{ 0xe048, @":^)" },
	{ 0xe04e, @"O:)" },
	{ 0xe056, @":)" },
	{ 0xe057, @":D" },
	{ 0xe058, @":(" },
	{ 0xe059, @">:(" },
	{ 0xe05a, @"~<:)" },
	{ 0xe105, @";P" },
	{ 0xe106, @"(<3" },
	{ 0xe107, @":O" },
	{ 0xe108, @"-_-'" },
	{ 0xe11a, @">:)" },
	{ 0xe401, @":'(" },
	{ 0xe402, @":j" },
	{ 0xe403, @":|" },
	{ 0xe404, @":-!" },
	{ 0xe405, @";)" },
	{ 0xe406, @"><" },
	{ 0xe407, @":X" },
	{ 0xe408, @";'(" },
	{ 0xe409, @":P" },
	{ 0xe40a, @":->" },
	{ 0xe40b, @":o" },
	{ 0xe40c, @":-&" },
	{ 0xe40d, @"O.O" },
	{ 0xe40e, @":/" },
	{ 0xe40f, @":'o" },
	{ 0xe410, @"x_x" },
	{ 0xe411, @":\"o" },
	{ 0xe412, @":'D" },
	{ 0xe413, @";(" },
	{ 0xe414, @":[" },
	{ 0xe415, @"^-^" },
	{ 0xe416, @"}:(" },
	{ 0xe417, @":-*" },
	{ 0xe418, @";-*" },
	{ 0xe421, @"(N)" },
	{ 0xe445, @"(~~)" },
	{ 0xe50c, @"**==" },
	{ 0, nil }
};

static const struct EmojiEmoticonPair emoticonToEmojiList[] = {
// Most Common
	{ 0xe056, @":)" },
	{ 0xe056, @"=)" },
	{ 0xe058, @":(" },
	{ 0xe058, @"=(" },
	{ 0xe405, @";)" },
	{ 0xe409, @":P" },
	{ 0xe409, @":p" },
	{ 0xe409, @"=P" },
	{ 0xe409, @"=p" },
	{ 0xe105, @";p" },
	{ 0xe105, @";P" },
	{ 0xe057, @":D" },
	{ 0xe057, @"=D" },
	{ 0xe403, @":|" },
	{ 0xe403, @"=|" },
	{ 0xe40e, @":/" },
	{ 0xe40e, @":\\" },
	{ 0xe40e, @"=/" },
	{ 0xe40e, @"=\\" },
	{ 0xe414, @":[" },
	{ 0xe414, @"=[" },
	{ 0xe056, @":]" },
	{ 0xe056, @"=]" },
	{ 0xe40b, @":o" },
	{ 0xe107, @":O" },
	{ 0xe40b, @"=o" },
	{ 0xe107, @"=O" },
	{ 0xe107, @":0" },
	{ 0xe107, @"=0" },
	{ 0xe04e, @"O:)" },
	{ 0xe04e, @"0:)" },
	{ 0xe04e, @"o:)" },
	{ 0xe04e, @"O=)" },
	{ 0xe04e, @"0=)" },
	{ 0xe04e, @"o=)" },
	{ 0xe022, @"<3" },
	{ 0xe023, @"</3" },
	{ 0xe023, @"<\3" },
	{ 0xe406, @"><" },
	{ 0xe40d, @"O.O" },
	{ 0xe40d, @"o.o" },
	{ 0xe40d, @"O.o" },
	{ 0xe40d, @"o.O" },
	{ 0xe409, @"XD" },
	{ 0xe409, @"xD" },
	{ 0xe407, @":X" },
	{ 0xe407, @":x" },
	{ 0xe407, @"=X" },
	{ 0xe407, @"=x" },
	{ 0xe059, @">:(" },
	{ 0xe11a, @">:)" },
	{ 0xe415, @"^.^" },
	{ 0xe415, @"^-^" },
	{ 0xe415, @"^_^" },

// Less Common
	{ 0xe056, @"(:" },
	{ 0xe056, @"(=" },
	{ 0xe056, @"[:" },
	{ 0xe056, @"[=" },
	{ 0xe058, @"):" },
	{ 0xe058, @")=" },
	{ 0xe058, @"]=" },
	{ 0xe058, @"]:" },
	{ 0xe056, @":-)" },
	{ 0xe056, @"=-)" },
	{ 0xe058, @":-(" },
	{ 0xe409, @":-P" },
	{ 0xe409, @":-p" },
	{ 0xe409, @"=-P" },
	{ 0xe409, @"=-p" },
	{ 0xe105, @";-p" },
	{ 0xe105, @";-P" },
	{ 0xe405, @";-)" },
	{ 0xe057, @":-D" },
	{ 0xe057, @"=-D" },
	{ 0xe058, @"=-(" },
	{ 0xe059, @">=(" },
	{ 0xe11a, @">=)" },
	{ 0xe414, @":-[" },
	{ 0xe414, @"=-[" },
	{ 0xe107, @":-0" },
	{ 0xe107, @"=-0" },
	{ 0xe04e, @"O=-)" },
	{ 0xe04e, @"o=-)" },
	{ 0xe108, @"-_-'" },
	{ 0xe403, @"-_-" },
	{ 0xe409, @"Xd" },
	{ 0xe409, @"xd" },
	{ 0xe409, @";D" },
	{ 0xe409, @"D:" },
	{ 0xe409, @"D:<" },
	{ 0xe406, @">_<" },
	{ 0xe410, @"X_X" },
	{ 0xe410, @"x_x" },
	{ 0xe410, @"X_x" },
	{ 0xe410, @"x_X" },
	{ 0xe410, @"x.x" },
	{ 0xe410, @"X.X" },
	{ 0xe410, @"X.x" },
	{ 0xe410, @"x.X" },
	{ 0xe417, @":*" },
	{ 0xe417, @":-*" },
	{ 0xe417, @"=*" },
	{ 0xe417, @"=-*" },
	{ 0xe418, @";*" },
	{ 0xe418, @";-*" },
	{ 0xe401, @":'(" },
	{ 0xe401, @"='(" },
	{ 0xe404, @":!" },
	{ 0xe404, @":-!" },
	{ 0xe404, @"=!" },
	{ 0xe404, @"=-!" },
	{ 0xe40c, @":&" },
	{ 0xe40c, @":-&" },
	{ 0xe40c, @"=&" },
	{ 0xe40c, @"=-&" },
	{ 0xe40c, @":#" },
	{ 0xe40c, @":-#" },
	{ 0xe40c, @"=#" },
	{ 0xe40c, @"=-#" },
	{ 0xe411, @":\"o" },
	{ 0xe411, @"=\"o" },
	{ 0xe411, @":\"O" },
	{ 0xe411, @"=\"O" },
	{ 0xe412, @":'D" },
	{ 0xe412, @"='D" },
	{ 0xe413, @";(" },
	{ 0xe408, @";'(" },
	{ 0xe40f, @":'o" },
	{ 0xe40f, @":'O" },
	{ 0xe40f, @"='o" },
	{ 0xe40f, @"='O" },
	{ 0xe40e, @":-/" },
	{ 0xe40e, @":-\\" },
	{ 0xe40e, @"=-/" },
	{ 0xe40e, @"=-\\" },
	{ 0xe40b, @":-o" },
	{ 0xe107, @":-O" },
	{ 0xe40b, @"=-o" },
	{ 0xe107, @"=-O" },
	{ 0xe402, @":j" },
	{ 0xe402, @":-j" },
	{ 0xe402, @"=j" },
	{ 0xe402, @"=-j" },
	{ 0xe40a, @":>" },
	{ 0xe40a, @":->" },
	{ 0xe40a, @"=>" },
	{ 0xe40a, @"=->" },
	{ 0xe416, @"}:(" },
	{ 0xe416, @"}:-(" },
	{ 0xe416, @"}=(" },
	{ 0xe416, @"}=-(" },
	{ 0xe059, @">:-(" },
	{ 0xe11a, @">:-)" },
	{ 0xe059, @">=-(" },
	{ 0xe11a, @">=-)" },
	{ 0xe04e, @"O:-)" },
	{ 0xe04e, @"o:-)" },

// Rare
	{ 0xe05a, @"~<:)" },
	{ 0xe048, @":^)" },
	{ 0xe048, @";^)" },
	{ 0xe048, @"=^)" },
	{ 0xe032, @"@};-" },
	{ 0xe032, @"@>-" },
	{ 0xe032, @"-;{@" },
	{ 0xe032, @"-<@" },
	{ 0xe445, @"(~~)" },
	{ 0xe50c, @"**==" },
	{ 0xe00e, @"(Y)" },
	{ 0xe00e, @"(y)" },
	{ 0xe421, @"(N)" },
	{ 0xe421, @"(n)" },
	{ 0xe106, @"(<3" },
	{ 0xe409, @"d:" },
	{ 0xe409, @"d=" },
	{ 0xe409, @"d-:" },
	{ 0xe056, @"(-:" },
	{ 0xe056, @"(-=" },
	{ 0xe058, @")-:" },
	{ 0xe058, @")-=" },
	{ 0xe058, @"]-:" },
	{ 0xe058, @"]-=" },
	{ 0xe401, @")':" },
	{ 0xe401, @")'=" },
	{ 0xe404, @"!:" },
	{ 0xe404, @"!-:" },
	{ 0xe404, @"!-=" },
	{ 0xe40b, @"o:" },
	{ 0xe107, @"O:" },
	{ 0xe40b, @"o-:" },
	{ 0xe107, @"O-:" },
	{ 0xe40b, @"o=" },
	{ 0xe107, @"O=" },
	{ 0xe40b, @"o-=" },
	{ 0xe107, @"O-=" },
	{ 0xe107, @"0:" },
	{ 0xe107, @"0-:" },
	{ 0xe107, @"0=" },
	{ 0xe107, @"0-=" },
	{ 0xe418, @"*;" },
	{ 0xe418, @"*-;" },
	{ 0xe417, @"*:" },
	{ 0xe417, @"*-:" },
	{ 0xe417, @"*=" },
	{ 0xe417, @"*-=" },
	{ 0xe11a, @"(:<" },
	{ 0xe059, @"):<" },
	{ 0xe11a, @"(-:<" },
	{ 0xe059, @")-:<" },
	{ 0xe11a, @"(=<" },
	{ 0xe059, @")=<" },
	{ 0xe11a, @"(-=<" },
	{ 0xe059, @")-=<" },
	{ 0xe04e, @"(:O" },
	{ 0xe04e, @"(:o" },
	{ 0xe04e, @"(-:O" },
	{ 0xe04e, @"(-:o" },
	{ 0xe04e, @"(=O" },
	{ 0xe04e, @"(=o" },
	{ 0xe04e, @"(-=O" },
	{ 0xe04e, @"(-=o" },
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
	{ 0xff, 0xff, 0xff },  /* 00) white */
	{ 0x00, 0x00, 0x00 },  /* 01) black */
	{ 0x00, 0x00, 0x7b },  /* 02) blue */
	{ 0x00, 0x94, 0x00 },  /* 03) green */
	{ 0xff, 0x00, 0x00 },  /* 04) red */
	{ 0x7b, 0x00, 0x00 },  /* 05) brown */
	{ 0x9c, 0x00, 0x9c },  /* 06) purple */
	{ 0xff, 0x7b, 0x00 },  /* 07) orange */
	{ 0xff, 0xff, 0x00 },  /* 08) yellow */
	{ 0x00, 0xff, 0x00 },  /* 09) bright green */
	{ 0x00, 0x94, 0x94 },  /* 10) cyan */
	{ 0x00, 0xff, 0xff },  /* 11) bright cyan */
	{ 0x00, 0x00, 0xff },  /* 12) bright blue */
	{ 0xff, 0x00, 0xff },  /* 13) bright purple */
	{ 0x7b, 0x7b, 0x7b },  /* 14) gray */
	{ 0xd6, 0xd6, 0xd6 }   /* 15) light gray */
};

static const unsigned char CTCPColors[][3] = {
	{ 0x00, 0x00, 0x00 },  /* 0) black */
	{ 0x00, 0x00, 0x7f },  /* 1) blue */
	{ 0x00, 0x7f, 0x00 },  /* 2) green */
	{ 0x00, 0x7f, 0x7f },  /* 3) cyan */
	{ 0x7f, 0x00, 0x00 },  /* 4) red */
	{ 0x7f, 0x00, 0x7f },  /* 5) purple */
	{ 0x7f, 0x7f, 0x00 },  /* 6) brown */
	{ 0xc0, 0xc0, 0xc0 },  /* 7) light gray */
	{ 0x7f, 0x7f, 0x7f },  /* 8) gray */
	{ 0x00, 0x00, 0xff },  /* 9) bright blue */
	{ 0x00, 0xff, 0x00 },  /* A) bright green */
	{ 0x00, 0xff, 0xff },  /* B) bright cyan */
	{ 0xff, 0x00, 0x00 },  /* C) bright red */
	{ 0xff, 0x00, 0xff },  /* D) bright magenta */
	{ 0xff, 0xff, 0x00 },  /* E) yellow */
	{ 0xff, 0xff, 0xff }   /* F) white */
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

@interface NSString (NewInLeopard)
- (NSArray *) componentsSeparatedByCharactersInSet:(NSCharacterSet *) characters;
@end

@implementation NSString (NSStringAdditions)
+ (NSString *) locallyUniqueString {
	struct timeval tv;
	gettimeofday( &tv, NULL );

	NSUInteger m = 36; // base (denominator)
	NSUInteger q = [[NSProcessInfo processInfo] processIdentifier] ^ tv.tv_usec; // input (quotient)
	NSUInteger r = 0; // remainder

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

	baseConvert;

	#undef baseConvert

	return [uniqueId autorelease];
}

#if ENABLE(SCRIPTING)
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
#endif

#pragma mark -

+ (NSArray *) knownEmoticons {
	static NSMutableArray *knownEmoticons;
	if( ! knownEmoticons ) {
		knownEmoticons = [[NSMutableArray alloc] initWithCapacity:350];
		for (const struct EmojiEmoticonPair *entry = emoticonToEmojiList; entry && entry->emoticon; ++entry)
			[knownEmoticons addObject:entry->emoticon];
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
			[emojiString release];
		}
	}

	return knownEmoji;
}

#pragma mark -

- (id) initWithChatData:(NSData *) data encoding:(NSStringEncoding) encoding {
	if( ! encoding ) encoding = NSISOLatin1StringEncoding;

	// Search for CTCP/2 encoding tags and act on them
	NSMutableData *newData = [NSMutableData dataWithCapacity:data.length];
	NSStringEncoding currentEncoding = encoding;

	const char *bytes = [data bytes];
	NSUInteger length = data.length;
	NSUInteger i = 0, j = 0, start = 0, end = 0;
	for( i = 0, start = 0; i < length; i++ ) {
		if( bytes[i] == '\006' ) {
			end = i;
			j = ++i;

			for( ; i < length && bytes[i] != '\006'; i++ );
			if( i >= length ) break;
			if( i == j ) continue;

			if( bytes[j++] == 'E' ) {
				NSString *encodingStr = [[NSString allocWithZone:nil] initWithBytes:( bytes + j ) length:( i - j ) encoding:NSASCIIStringEncoding];
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

				[encodingStr release];

				if( newEncoding && newEncoding != currentEncoding ) {
					if( ( end - start ) > 0 ) {
						NSData *subData = nil;
						if( currentEncoding != NSUTF8StringEncoding ) {
							NSString *tempStr = [[NSString allocWithZone:nil] initWithBytes:( bytes + start ) length:( end - start ) encoding:currentEncoding];
							NSData *utf8Data = [tempStr dataUsingEncoding:NSUTF8StringEncoding];
							if( utf8Data ) subData = [utf8Data retain];
							[tempStr release];
						} else {
							subData = [[NSData allocWithZone:nil] initWithBytesNoCopy:(void *)( bytes + start ) length:( end - start )];
						}

						if( subData ) [newData appendData:subData];
						[subData release];
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
				NSString *tempStr = [[NSString allocWithZone:nil] initWithBytes:( bytes + start ) length:( length - start ) encoding:currentEncoding];
				NSData *utf8Data = [tempStr dataUsingEncoding:NSUTF8StringEncoding];
				if( utf8Data ) subData = [utf8Data retain];
				[tempStr release];
			} else {
				subData = [[NSData allocWithZone:nil] initWithBytesNoCopy:(void *)( bytes + start ) length:( length - start )];
			}

			if( subData ) [newData appendData:subData];
			[subData release];
		}

		encoding = NSUTF8StringEncoding;
		data = newData;
	}

	if( encoding != NSUTF8StringEncoding && isValidUTF8( [data bytes], data.length ) )
		encoding = NSUTF8StringEncoding;

	NSString *message = [[NSString allocWithZone:nil] initWithData:data encoding:encoding];
	if( ! message ) {
		[self release];
		return nil;
	}

	NSCharacterSet *formatCharacters = [NSCharacterSet characterSetWithCharactersInString:@"\002\003\006\026\037\017"];

	// if the message dosen't have any formatting chars just init as a plain string and return quickly
	if( [message rangeOfCharacterFromSet:formatCharacters].location == NSNotFound ) {
		self = [self initWithString:[message stringByEncodingXMLSpecialCharactersAsEntities]];
		[message release];
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
					case 'C': // color
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
					case 'F': // font size
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

	[message release];

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

+ (NSString *) stringByReversingString:(NSString *) normalString {
	NSMutableString *reversedString = [[NSMutableString alloc] initWithCapacity:normalString.length];

	for (NSInteger index = normalString.length - 1; index >= 0; index--)
		[reversedString appendString:[normalString substringWithRange:NSMakeRange(index, 1)]];

	return [reversedString autorelease];
}

#pragma mark -

- (NSString *) stringByEncodingXMLSpecialCharactersAsEntities {
	NSCharacterSet *special = [NSCharacterSet characterSetWithCharactersInString:@"&<>\"'"];
	NSRange range = [self rangeOfCharacterFromSet:special options:NSLiteralSearch];
	if( range.location == NSNotFound )
		return self;

	NSMutableString *result = [self mutableCopyWithZone:nil];
	[result encodeXMLSpecialCharactersAsEntities];
	return [result autorelease];
}

- (NSString *) stringByDecodingXMLSpecialCharacterEntities {
	NSRange range = [self rangeOfString:@"&" options:NSLiteralSearch];
	if( range.location == NSNotFound )
		return self;

	NSMutableString *result = [self mutableCopyWithZone:nil];
	[result decodeXMLSpecialCharacterEntities];
	return [result autorelease];
}

#pragma mark -

- (NSString *) stringByEscapingCharactersInSet:(NSCharacterSet *) set {
	NSRange range = [self rangeOfCharacterFromSet:set];
	if( range.location == NSNotFound )
		return self;

	NSMutableString *result = [self mutableCopyWithZone:nil];
	[result escapeCharactersInSet:set];
	return [result autorelease];
}

- (NSString *) stringByReplacingCharactersInSet:(NSCharacterSet *) set withString:(NSString *) string {
	NSRange range = [self rangeOfCharacterFromSet:set];
	if( range.location == NSNotFound )
		return self;

	NSMutableString *result = [self mutableCopyWithZone:nil];
	[result replaceCharactersInSet:set withString:string];
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
	NSRange range = [self rangeOfCharacterFromSet:[NSCharacterSet illegalXMLCharacterSet]];

	if( range.location == NSNotFound )
		return self;

	NSMutableString *result = [self mutableCopyWithZone:nil];
	[result stripIllegalXMLCharacters];
	return [result autorelease];
}

- (NSString *) stringByStrippingXMLTags {
	if( [self rangeOfString:@"<"].location == NSNotFound )
		return self;

	NSMutableString *result = [self mutableCopyWithZone:nil];
	[result stripXMLTags];
	return [result autorelease];
}

#pragma mark -

- (NSString *) stringWithDomainNameSegmentOfAddress {
	NSString *ret = self;
	unsigned ip = 0;
	BOOL ipAddress = ( sscanf( [self UTF8String], "%u.%u.%u.%u", &ip, &ip, &ip, &ip ) == 4 );

	if( ! ipAddress ) {
		NSArray *parts = [self componentsSeparatedByString:@"."];
		NSUInteger count = parts.count;
		if( count > 2 )
			ret = [NSString stringWithFormat:@"%@.%@", [parts objectAtIndex:(count - 2)], [parts objectAtIndex:(count - 1)]];
	}

	return ret;
}

#pragma mark -

- (NSArray *) componentsSeparatedByCharactersInSet:(NSCharacterSet *) separator limit:(NSUInteger) limit {
	return [self componentsSeparatedByCharactersInSet:separator limit:limit remainingString:NULL];
}

- (NSArray *) componentsSeparatedByCharactersInSet:(NSCharacterSet *) separator limit:(NSUInteger) limit remainingString:(NSString **) remainder {
	if( ! limit && ! remainder && [self respondsToSelector:@selector(componentsSeparatedByCharactersInSet:)] )
		return [self componentsSeparatedByCharactersInSet:separator];

	if( [self rangeOfCharacterFromSet:separator].location == NSNotFound )
		return [NSArray arrayWithObject:self];

	if( ! limit ) limit = ULONG_MAX;

	NSScanner *scanner = [[NSScanner allocWithZone:nil] initWithString:self];
	[scanner setCharactersToBeSkipped:nil];

	NSMutableArray *result = [[NSMutableArray allocWithZone:nil] init];

	NSUInteger count = 0;
	NSString *component = @"";
	while( ! [scanner isAtEnd] ) {
		[scanner scanUpToCharactersFromSet:separator intoString:&component];
		[scanner scanCharactersFromSet:separator intoString:NULL];

		[result addObject:component];

		if (++count >= limit)
			break;
	}

	if( remainder )
		*remainder = [self substringFromIndex:[scanner scanLocation]];

	[scanner release];

	return [result autorelease];
}

#pragma mark -

- (NSString *) fileName {
	NSString *fileName = [self lastPathComponent];
	NSString *fileExtension = [NSString stringWithFormat:@".%@", [self pathExtension]];

	return [fileName stringByReplacingOccurrencesOfString:fileExtension withString:@""];
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
		emojiCharacters = [[NSCharacterSet characterSetWithRange:NSMakeRange(0xe001, (0xe53e - 0xe001))] retain];
	return [self rangeOfCharacterFromSet:emojiCharacters options:NSLiteralSearch range:range];
}

- (BOOL) containsTypicalEmoticonCharacters {
	if (!typicalEmoticonCharacters)
		typicalEmoticonCharacters = [[NSCharacterSet characterSetWithCharactersInString:@";:=-()^><_."] retain];
	return ([self rangeOfCharacterFromSet:typicalEmoticonCharacters options:NSLiteralSearch].location != NSNotFound || [self hasCaseInsensitiveSubstring:@"XD"]);
}

- (NSString *) stringBySubstitutingEmojiForEmoticons {
	if (![self containsEmojiCharacters])
		return self;
	NSMutableString *result = [self mutableCopyWithZone:nil];
	[result substituteEmojiForEmoticons];
	return [result autorelease];
}

- (NSString *) stringBySubstitutingEmoticonsForEmoji {
	if (![self containsTypicalEmoticonCharacters])
		return self;
	NSMutableString *result = [self mutableCopyWithZone:nil];
	[result substituteEmoticonsForEmoji];
	return [result autorelease];
}
@end

#pragma mark -

@implementation NSMutableString (NSMutableStringAdditions)
- (void) encodeXMLSpecialCharactersAsEntities {
	NSCharacterSet *special = [NSCharacterSet characterSetWithCharactersInString:@"&<>\"'"];
	NSRange range = [self rangeOfCharacterFromSet:special options:NSLiteralSearch];
	if( range.location == NSNotFound )
		return;

	[self replaceOccurrencesOfString:@"&" withString:@"&amp;" options:NSLiteralSearch range:NSMakeRange( 0, self.length )];
	[self replaceOccurrencesOfString:@"<" withString:@"&lt;" options:NSLiteralSearch range:NSMakeRange( 0, self.length )];
	[self replaceOccurrencesOfString:@">" withString:@"&gt;" options:NSLiteralSearch range:NSMakeRange( 0, self.length )];
	[self replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:NSLiteralSearch range:NSMakeRange( 0, self.length )];
	[self replaceOccurrencesOfString:@"'" withString:@"&apos;" options:NSLiteralSearch range:NSMakeRange( 0, self.length )];
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

	NSScanner *scanner = [[NSScanner allocWithZone:nil] initWithString:self];

	NSUInteger offset = 0;
	while( ! [scanner isAtEnd] ) {
		[scanner scanUpToCharactersFromSet:set intoString:nil];
		if( ! [scanner isAtEnd] ) {
			[self insertString:@"\\" atIndex:[scanner scanLocation] + offset++];
			[scanner setScanLocation:[scanner scanLocation] + 1];
		}
	}

	[scanner release];
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

	NSCharacterSet *escapedCharacters = [NSCharacterSet characterSetWithCharactersInString:@"^[]{}()\\.$*+?|"];
	for (const struct EmojiEmoticonPair *entry = emoticonToEmojiList; entry && entry->emoticon; ++entry) {
		NSString *searchEmoticon = (encoded ? [entry->emoticon stringByEncodingXMLSpecialCharactersAsEntities] : entry->emoticon);
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

		[emoticon release];
		[searchRegex release];
		[emojiString release];

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
				NSString *emoticon = entry->emoticon;
				if (encode) emoticon = [emoticon stringByEncodingXMLSpecialCharactersAsEntities];

				NSString *replacement = nil;
				if (emojiRange.location == 0 && (emojiRange.location + 1) == self.length)
					replacement = [emoticon retain];
				else if (emojiRange.location > 0 && (emojiRange.location + 1) == self.length && [self characterAtIndex:(emojiRange.location - 1)] == ' ')
					replacement = [emoticon retain];
				else if ([self characterAtIndex:(emojiRange.location - 1)] == ' ' || ((emojiRange.location + 1) < self.length && [self characterAtIndex:(emojiRange.location + 1)] == ' '))
					replacement = [emoticon retain];
				else if (emojiRange.location == 0 || [self characterAtIndex:(emojiRange.location - 1)] == ' ')
					replacement = [[NSString alloc] initWithFormat:@"%@ ", emoticon];
				else if ((emojiRange.location + 1) == self.length || [self characterAtIndex:(emojiRange.location + 1)] == ' ')
					replacement = [[NSString alloc] initWithFormat:@" %@", emoticon];
				else replacement = [[NSString alloc] initWithFormat:@" %@ ", emoticon];

				[self replaceCharactersInRange:NSMakeRange(emojiRange.location, 1) withString:replacement];

				range->length += (replacement.length - 1);

				[replacement release];
				break;
			}
		}

		if (emojiRange.location >= NSMaxRange(*range))
			return;

		emojiRange = [self rangeOfEmojiCharactersInRange:NSMakeRange(emojiRange.location + 1, (NSMaxRange(*range) - emojiRange.location - 1))];
	}
}
@end
