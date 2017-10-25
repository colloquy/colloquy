#import "NSAttributedStringAdditions.h"
#import "NSColorAdditions.h"
#import "NSStringAdditions.h"
#import "NSScannerAdditions.h"
#import <CoreFoundation/CFString.h>
#import <CoreFoundation/CFStringEncodingExt.h>

NS_ASSUME_NONNULL_BEGIN

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

#if SYSTEM(MAC)
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
#endif

static unsigned short colorRGBToMIRCColor( unsigned char red, unsigned char green, unsigned char blue ) {
	unsigned short color = 1;
	NSUInteger distance = NSUIntegerMax;

	for( unsigned short i = 0; i < 16; ++i ) {
		NSUInteger o = abs( red - mIRCColors[i][0] ) + abs( green - mIRCColors[i][1] ) + abs( blue - mIRCColors[i][2] );
		if( o < distance ) {
			color = i;
			distance = o;
		}
	}

	return color;
}

#if SYSTEM(MAC)
static BOOL scanOneOrTwoDigits( NSScanner *scanner, NSUInteger *number ) {
	NSCharacterSet *characterSet = [NSCharacterSet decimalDigitCharacterSet];
	NSString *chars = nil;

	if( ! [scanner scanCharactersFromSet:characterSet maxLength:2 intoString:&chars] )
		return NO;

	*number = [chars intValue];
	return YES;
}

static void setItalicOrObliqueFont( NSMutableDictionary *attrs ) {
	NSFontManager *fm = [NSFontManager sharedFontManager];
	NSFont *font = attrs[NSFontAttributeName];
	if( ! font ) font = [NSFont userFontOfSize:12];
	if( ! ( [fm traitsOfFont:font] & NSItalicFontMask ) ) {
		NSFont *newFont = [fm convertFont:font toHaveTrait:NSItalicFontMask];
		if( newFont == font ) { // font couldn't be made italic
			attrs[NSObliquenessAttributeName] = @(JVItalicObliquenessValue);
		} else { // we got an italic font
			attrs[NSFontAttributeName] = newFont;
			[attrs removeObjectForKey:NSObliquenessAttributeName];
		}
	}
}

static void removeItalicOrObliqueFont( NSMutableDictionary *attrs ) {
	NSFontManager *fm = [NSFontManager sharedFontManager];
	NSFont *font = attrs[NSFontAttributeName];
	if( ! font ) font = [NSFont userFontOfSize:12];
	if( [fm traitsOfFont:font] & NSItalicFontMask ) {
		font = [fm convertFont:font toNotHaveTrait:NSItalicFontMask];
		attrs[NSFontAttributeName] = font;
	}

	[attrs removeObjectForKey:NSObliquenessAttributeName];
}
#endif

NSString *NSChatWindowsIRCFormatType = @"NSChatWindowsIRCFormatType";
NSString *NSChatCTCPTwoFormatType = @"NSChatCTCPTwoFormatType";

#pragma mark -

@implementation NSAttributedString (NSAttributedStringHTMLAdditions)
#if SYSTEM(MAC)
+ (instancetype) attributedStringWithHTMLFragment:(NSString *) fragment {
	NSParameterAssert( fragment != nil );

	NSMutableDictionary *options = [[NSMutableDictionary alloc] initWithObjectsAndKeys:@(NSUTF8StringEncoding), NSCharacterEncodingDocumentOption, nil];

	// we suround the fragment in the #01FE02 green color so we can later key it out and strip it
	// this will result in colorless areas of our string, letting the color be defined by the interface

	NSString *render = [[NSString alloc] initWithFormat:@"<span style=\"color: #01FE02\">%@</span>", fragment];
	NSData *HTMLData = [render dataUsingEncoding:NSUTF8StringEncoding];
	NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithHTML:HTMLData options:options documentAttributes:NULL];

	NSRange limitRange, effectiveRange;
	limitRange = NSMakeRange( 0, result.length );
	while( limitRange.length > 0 ) {
		NSColor *color = [result attribute:NSForegroundColorAttributeName atIndex:limitRange.location longestEffectiveRange:&effectiveRange inRange:limitRange];
		if( [[color HTMLAttributeValue] isEqualToString:@"#01FE02"] ) // strip the color if it matched
			[result removeAttribute:NSForegroundColorAttributeName range:effectiveRange];
		limitRange = NSMakeRange( NSMaxRange( effectiveRange ), NSMaxRange( limitRange ) - NSMaxRange( effectiveRange ) );
	}

	NSAttributedString *ret = [[self alloc] initWithAttributedString:result];

	return ret;
}

- (NSString *) HTMLFormatWithOptions:(NSDictionary *) options {
	NSRange limitRange, effectiveRange;
	NSMutableString *ret = [NSMutableString string];

	if( [options[@"FullDocument"] boolValue] )
		[ret appendString:@"<html><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"></head><body>"];

	limitRange = NSMakeRange( 0, self.length );
	while( limitRange.length > 0 ) {
		NSDictionary *dict = [self attributesAtIndex:limitRange.location longestEffectiveRange:&effectiveRange inRange:limitRange];

		id link = dict[NSLinkAttributeName];
		NSFont *currentFont = dict[NSFontAttributeName];
		NSColor *foregoundColor = dict[NSForegroundColorAttributeName];
		NSColor *backgroundColor = dict[NSBackgroundColorAttributeName];
		NSString *htmlStart = dict[@"XHTMLStart"];
		NSString *htmlEnd = dict[@"XHTMLEnd"];
		NSSet *classes = dict[@"CSSClasses"];
		NSString *style = dict[@"CSSText"];
		NSString *title = dict[@"LinkTitle"];
		BOOL bold = NO, italic = NO, underline = NO, strikethrough = NO;

		NSMutableString *spanString = [NSMutableString stringWithString:@"<span"];
		NSMutableString *styleString = [NSMutableString stringWithString:( style ? style : @"" )];

		if( foregoundColor && ! [options[@"IgnoreFontColors"] boolValue] ) {
			if( styleString.length && ! [styleString hasSuffix:@";"] ) [styleString appendString:@";"];
			[styleString appendFormat:@"color: %@", [foregoundColor CSSAttributeValue]];
		}

		if( backgroundColor && ! [options[@"IgnoreFontColors"] boolValue] ) {
			if( styleString.length && ! [styleString hasSuffix:@";"] ) [styleString appendString:@";"];
			[styleString appendFormat:@"background-color: %@", [backgroundColor CSSAttributeValue]];
		}

		if( ! [options[@"IgnoreFonts"] boolValue] ) {
			if( styleString.length && ! [styleString hasSuffix:@";"] ) [styleString appendString:@";"];
			NSString *family = [currentFont familyName];
			if( [family rangeOfString:@" "].location != NSNotFound )
				family = [NSString stringWithFormat:@"'%@'", family];
			[styleString appendFormat:@"font-family: %@", family];
		}

		if( ! [options[@"IgnoreFontSizes"] boolValue] ) {
			if( styleString.length && ! [styleString hasSuffix:@";"] ) [styleString appendString:@";"];
			[styleString appendFormat:@"font-size: %.1fpt", [currentFont pointSize]];
		}

		if( ! [options[@"IgnoreFontTraits"] boolValue] ) {
			NSFontTraitMask traits = [[NSFontManager sharedFontManager] traitsOfFont:currentFont];
			if( traits & NSBoldFontMask ) bold = YES;
			if( traits & NSItalicFontMask) italic = YES;
			NSNumber *oblique = dict[NSObliquenessAttributeName];
			if( oblique && [oblique floatValue] > 0. ) italic = YES;
			if( [dict[NSUnderlineStyleAttributeName] boolValue] ) underline = YES;
			if( [dict[NSStrikethroughStyleAttributeName] boolValue] ) strikethrough = YES;
		}

		if( styleString.length ) [spanString appendFormat:@" style=\"%@\"", styleString];
		if( classes.count ) [spanString appendFormat:@" class=\"%@\"", [[classes allObjects] componentsJoinedByString:@" "]];
		[spanString appendString:@">"];

		if( classes.count || styleString.length ) [ret appendString:spanString];
		if( bold ) [ret appendString:@"<b>"];
		if( italic ) [ret appendString:@"<i>"];
		if( underline ) [ret appendString:@"<u>"];
		if( strikethrough ) [ret appendString:@"<s>"];
		if( htmlStart.length ) [ret appendString:htmlStart];
		if( link ) {
			[ret appendFormat:@"<a href=\"%@\"", [[link description] stringByEncodingXMLSpecialCharactersAsEntities]];
			if( title ) [ret appendFormat:@" title=\"%@\"", [title stringByEncodingXMLSpecialCharactersAsEntities]];
			[ret appendString:@">"];
		}

		[ret appendString:[[[self attributedSubstringFromRange:effectiveRange] string] stringByEncodingXMLSpecialCharactersAsEntities]];

		if( link ) [ret appendString:@"</a>"];
		if( htmlEnd.length ) [ret appendString:htmlEnd];
		if( strikethrough ) [ret appendString:@"</s>"];
		if( underline ) [ret appendString:@"</u>"];
		if( italic ) [ret appendString:@"</i>"];
		if( bold ) [ret appendString:@"</b>"];
		if( classes.count || styleString.length ) [ret appendString:@"</span>"];

		limitRange = NSMakeRange( NSMaxRange( effectiveRange ), NSMaxRange( limitRange ) - NSMaxRange( effectiveRange ) );
	}

	if( [options[@"FullDocument"] boolValue] )
		[ret appendString: @"</body></html>"];

	return ret;
}
#endif

#pragma mark -

#if SYSTEM(MAC)
+ (instancetype) attributedStringWithChatFormat:(NSData *) data options:(NSDictionary *) options {
	return [[self alloc] initWithChatFormat:data options:options];
}
#endif

#if SYSTEM(MAC)
- (instancetype) initWithChatFormat:(NSData *) data options:(NSDictionary *) options {
	NSStringEncoding encoding = [options[@"StringEncoding"] unsignedLongValue];
	if( ! encoding ) encoding = NSISOLatin1StringEncoding;

	// Search for CTCP/2 encoding tags and act on them
	NSMutableData *newData = [NSMutableData dataWithCapacity:data.length];
	const char *bytes = [data bytes];
	NSUInteger length = data.length;
	NSUInteger i = 0, j = 0, start = 0, end = 0;
	NSStringEncoding currentEncoding = encoding;
	for( i = 0, start = 0; i < length; i++ ) {
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

	NSString *message = [[NSString alloc] initWithBytes:[data bytes] length:data.length encoding:encoding];
	if( ! message ) {
		return nil;
	}

	NSCharacterSet *formatCharacters = [NSCharacterSet characterSetWithCharactersInString:@"\002\003\006\026\037\017"];
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

	NSFont *baseFont = options[@"BaseFont"];
	if( ! baseFont ) baseFont = [NSFont userFontOfSize:12.];
	attributes[NSFontAttributeName] = baseFont;

	// if the message dosen't have any formatting chars just init as a plain string and return quickly
	if( [message rangeOfCharacterFromSet:formatCharacters].location == NSNotFound )
		return [self initWithString:message attributes:attributes];

	NSMutableAttributedString *ret = [[NSMutableAttributedString alloc] init];
	NSScanner *scanner = [NSScanner scannerWithString:message];
	[scanner setCharactersToBeSkipped:nil]; // don't skip leading whitespace!

	char boldStack = 0, italicStack = 0, underlineStack = 0, strikeStack = 0;

	while( ! [scanner isAtEnd] ) {
		NSString *cStr = nil;
		if( [scanner scanCharactersFromSet:formatCharacters maxLength:1 intoString:&cStr] ) {
			unichar c = [cStr characterAtIndex:0];
			switch( c ) {
			case '\017': // reset all
			{
				boldStack = italicStack = underlineStack = strikeStack = 0;
				NSFont *oldFont = attributes[NSFontAttributeName];
				NSFont *font = oldFont ? [[NSFontManager sharedFontManager] convertFont:oldFont toNotHaveTrait:NSBoldFontMask] : oldFont;
				if( font ) attributes[NSFontAttributeName] = font;
				removeItalicOrObliqueFont( attributes );
				[attributes removeObjectForKey:NSStrikethroughStyleAttributeName];
				[attributes removeObjectForKey:NSUnderlineStyleAttributeName];
				[attributes removeObjectForKey:NSForegroundColorAttributeName];
				[attributes removeObjectForKey:NSBackgroundColorAttributeName];
				break;
			}
			case '\002': // toggle bold
			{
				boldStack = ! boldStack;

				NSFont *oldFont = attributes[NSFontAttributeName];
				if( boldStack && ! [options[@"IgnoreFontTraits"] boolValue] ) {
					NSFont *font = oldFont ? [[NSFontManager sharedFontManager] convertFont:oldFont toHaveTrait:NSBoldFontMask] : oldFont;
					if( font ) attributes[NSFontAttributeName] = font;
				} else if( ! [options[@"IgnoreFontTraits"] boolValue] ) {
					NSFont *font = oldFont ? [[NSFontManager sharedFontManager] convertFont:oldFont toNotHaveTrait:NSBoldFontMask] : oldFont;
					if( font ) attributes[NSFontAttributeName] = font;
				}
				break;
			}
			case '\026': // toggle italic
				italicStack = ! italicStack;
				if( italicStack && ! [options[@"IgnoreFontTraits"] boolValue] ) {
					setItalicOrObliqueFont( attributes );
				} else if( ! [options[@"IgnoreFontTraits"] boolValue] ) {
					removeItalicOrObliqueFont( attributes );
				}
				break;
			case '\037': // toggle underline
				underlineStack = ! underlineStack;
				if( underlineStack && ! [options[@"IgnoreFontTraits"] boolValue] ) attributes[NSUnderlineStyleAttributeName] = @1;
				else [attributes removeObjectForKey:NSUnderlineStyleAttributeName];
				break;
			case '\003': // color
			{
				NSUInteger fcolor = 0;
				if( scanOneOrTwoDigits( scanner, &fcolor ) ) {
					fcolor %= 16;

					NSColor *foregroundColor = [NSColor colorWithCalibratedRed:( (CGFloat) mIRCColors[fcolor][0] / 255. ) green:( (CGFloat) mIRCColors[fcolor][1] / 255. ) blue:( (CGFloat) mIRCColors[fcolor][2] / 255. ) alpha:1.];
					if( foregroundColor && ! [options[@"IgnoreFontColors"] boolValue] )
						attributes[NSForegroundColorAttributeName] = foregroundColor;

					NSUInteger bcolor = 0;
					if( [scanner scanString:@"," intoString:NULL] && scanOneOrTwoDigits( scanner, &bcolor ) && bcolor != 99 ) {
						bcolor %= 16;
						NSColor *backgroundColor = [NSColor colorWithCalibratedRed:( (CGFloat) mIRCColors[bcolor][0] / 255. ) green:( (CGFloat) mIRCColors[bcolor][1] / 255. ) blue:( (CGFloat) mIRCColors[bcolor][2] / 255. ) alpha:1.];
						if( backgroundColor && ! [options[@"IgnoreFontColors"] boolValue] )
							attributes[NSBackgroundColorAttributeName] = backgroundColor;
					}
				} else { // no color, reset both colors
					[attributes removeObjectForKey:NSForegroundColorAttributeName];
					[attributes removeObjectForKey:NSBackgroundColorAttributeName];
				}
				break;
			}
			case '\006': { // ctcp 2 formatting ( http://www.lag.net/~robey/ctcp/ctcp2.2.txt )
				if( ! [scanner isAtEnd] ) {
					BOOL off = NO;

					unichar formatChar = [message characterAtIndex:[scanner scanLocation]];
					[scanner setScanLocation:[scanner scanLocation]+1];

					switch( formatChar ) {
					case 'B': // bold
					{
						if( [scanner scanString:@"-" intoString:NULL] ) {
							if( boldStack >= 1 ) boldStack--;
							off = YES;
						} else { // on is the default
							[scanner scanString:@"+" intoString:NULL];
							boldStack++;
						}

						NSFont *oldFont = attributes[NSFontAttributeName];
						if( boldStack == 1 && ! off && ! [options[@"IgnoreFontTraits"] boolValue] ) {
							NSFont *font = oldFont ? [[NSFontManager sharedFontManager] convertFont:oldFont toHaveTrait:NSBoldFontMask] : oldFont;
							if( font ) attributes[NSFontAttributeName] = font;
						} else if( ! boldStack && ! [[options objectForKey:@"IgnoreFontTraits"] boolValue] ) {
							NSFont *font = oldFont ? [[NSFontManager sharedFontManager] convertFont:oldFont toNotHaveTrait:NSBoldFontMask] : oldFont;
							if( font ) attributes[NSFontAttributeName] = font;
						}
						break;
					}
					case 'I': // italic
						if( [scanner scanString:@"-" intoString:NULL] ) {
							if( italicStack >= 1 ) italicStack--;
							off = YES;
						} else { // on is the default
							[scanner scanString:@"+" intoString:NULL];
							italicStack++;
						}

						if( italicStack == 1 && ! off && ! [options[@"IgnoreFontTraits"] boolValue] ) {
							setItalicOrObliqueFont( attributes );
						} else if( ! italicStack && ! [options[@"IgnoreFontTraits"] boolValue] ) {
							removeItalicOrObliqueFont( attributes );
						}
						break;
					case 'U': // underline
						if( [scanner scanString:@"-" intoString:NULL] ) {
							if( underlineStack >= 1 ) underlineStack--;
							off = YES;
						} else { // on is the default
							[scanner scanString:@"+" intoString:NULL];
							underlineStack++;
						}

						if( underlineStack == 1 && ! off && ! [options[@"IgnoreFontTraits"] boolValue] ) {
							attributes[NSUnderlineStyleAttributeName] = @1;
						} else if( ! underlineStack ) {
							[attributes removeObjectForKey:NSUnderlineStyleAttributeName];
						}
						break;
					case 'S': // strikethrough
						if( [scanner scanString:@"-" intoString:NULL] ) {
							if( strikeStack >= 1 ) strikeStack--;
							off = YES;
						} else { // on is the default
							[scanner scanString:@"+" intoString:NULL];
							strikeStack++;
						}

						if( strikeStack == 1 && ! off && ! [options[@"IgnoreFontTraits"] boolValue] ) {
							attributes[NSStrikethroughStyleAttributeName] = @1;
						} else if( ! strikeStack ) {
							[attributes removeObjectForKey:NSStrikethroughStyleAttributeName];
						}
						break;
					case 'C': { // color
						if( [message characterAtIndex:[scanner scanLocation]] == '\006' ) { // reset colors
							[attributes removeObjectForKey:NSForegroundColorAttributeName];
							[attributes removeObjectForKey:NSBackgroundColorAttributeName];
							break;
						}
						// scan for foreground color
						NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"];
						NSString *colorStr = nil;
						BOOL foundForeground = YES;
						if( [scanner scanString:@"#" intoString:NULL] ) { // rgb hex color
							if( [scanner scanCharactersFromSet:hexSet maxLength:6 intoString:&colorStr] ) {
								NSColor *foregroundColor = [NSColor colorWithHTMLAttributeValue:colorStr];
								if( foregroundColor && ! [options[@"IgnoreFontColors"] boolValue] )
									attributes[NSForegroundColorAttributeName] = foregroundColor;
							}
						} else if( [scanner scanCharactersFromSet:hexSet maxLength:1 intoString:&colorStr] ) { // indexed color
							NSUInteger index = [colorStr characterAtIndex:0];
							if( index >= 'A' ) index -= ( 'A' - '9' - 1 );
							index -= '0';
							NSColor *foregroundColor = [NSColor colorWithCalibratedRed:( (CGFloat) CTCPColors[index][0] / 255. ) green:( (CGFloat) CTCPColors[index][1] / 255. ) blue:( (CGFloat) CTCPColors[index][2] / 255. ) alpha:1.];
							if( foregroundColor && ! [options[@"IgnoreFontColors"] boolValue] )
								attributes[NSForegroundColorAttributeName] = foregroundColor;
						} else if( [scanner scanString:@"." intoString:NULL] ) { // reset the foreground color
							[attributes removeObjectForKey:NSForegroundColorAttributeName];
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
								if( [scanner scanCharactersFromSet:hexSet maxLength:6 intoString:&colorStr] ) {
									NSColor *backgroundColor = [NSColor colorWithHTMLAttributeValue:colorStr];
									if( backgroundColor && ! [options[@"IgnoreFontColors"] boolValue] )
										attributes[NSBackgroundColorAttributeName] = backgroundColor;
								}
							} else if( [scanner scanCharactersFromSet:hexSet maxLength:1 intoString:&colorStr] ) { // indexed color
								NSUInteger index = [colorStr characterAtIndex:0];
								if( index >= 'A' ) index -= ( 'A' - '9' - 1 );
								index -= '0';
								NSColor *backgroundColor = [NSColor colorWithCalibratedRed:( (CGFloat) CTCPColors[index][0] / 255. ) green:( (CGFloat) CTCPColors[index][1] / 255. ) blue:( (CGFloat) CTCPColors[index][2] / 255. ) alpha:1.];
								if( backgroundColor && ! [options[@"IgnoreFontColors"] boolValue] )
									attributes[NSBackgroundColorAttributeName] = backgroundColor;
							} else if( [scanner scanString:@"." intoString:NULL] ) { // reset the background color
								[attributes removeObjectForKey:NSBackgroundColorAttributeName];
							} else [scanner scanString:@"-" intoString:NULL]; // skip the background color
						} else {
							// No colors - treat it like ..
							[attributes removeObjectForKey:NSForegroundColorAttributeName];
							[attributes removeObjectForKey:NSBackgroundColorAttributeName];
						}
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
						boldStack = italicStack = underlineStack = strikeStack = 0;
							NSFont *oldFont = attributes[NSFontAttributeName];
							NSFont *font = oldFont ? [[NSFontManager sharedFontManager] convertFont:oldFont toNotHaveTrait:NSBoldFontMask] : oldFont;
						if( font ) attributes[NSFontAttributeName] = font;
						removeItalicOrObliqueFont( attributes );
						[attributes removeObjectForKey:NSStrikethroughStyleAttributeName];
						[attributes removeObjectForKey:NSUnderlineStyleAttributeName];
						[attributes removeObjectForKey:NSForegroundColorAttributeName];
						[attributes removeObjectForKey:NSBackgroundColorAttributeName];
					}

					[scanner scanUpToString:@"\006" intoString:NULL];
					[scanner scanString:@"\006" intoString:NULL];
				}
			}
			}
		}

		NSString *text = nil;
 		[scanner scanUpToCharactersFromSet:formatCharacters intoString:&text];
		if( text.length ) {
			id new = [[[self class] alloc] initWithString:text attributes:attributes];
			[ret appendAttributedString:new];
		}
	}

	return [self initWithAttributedString:ret];
}
#endif

- (NSData *) _mIRCFormatWithOptions:(NSDictionary *) options {
	NSRange limitRange, effectiveRange;
	NSMutableData *ret = [[NSMutableData alloc] initWithCapacity:( self.length + 20 )];
	NSStringEncoding encoding = [options[@"StringEncoding"] unsignedLongValue];
	if( ! encoding ) encoding = NSISOLatin1StringEncoding;

	limitRange = NSMakeRange( 0, self.length );
	while( limitRange.length > 0 ) {
		NSDictionary *dict = [self attributesAtIndex:limitRange.location longestEffectiveRange:&effectiveRange inRange:limitRange];

		id link = dict[NSLinkAttributeName];
		BOOL bold = NO, italic = NO, underline = NO;
#if SYSTEM(MAC)
		NSFont *currentFont = dict[NSFontAttributeName];
		NSColor *foregroundColor = dict[NSForegroundColorAttributeName];
		NSColor *backgroundColor = dict[NSBackgroundColorAttributeName];
#else
		UIFont *currentFont = dict[NSFontAttributeName];
		UIColor *foregroundColor = dict[NSForegroundColorAttributeName];
		UIColor *backgroundColor = dict[NSBackgroundColorAttributeName];
#endif
		if( ! [options[@"IgnoreFontTraits"] boolValue] ) {
#if SYSTEM(MAC)
			NSFontTraitMask traits = [[NSFontManager sharedFontManager] traitsOfFont:currentFont];
			if( traits & NSBoldFontMask ) bold = YES;
			if( traits & NSItalicFontMask ) italic = YES;
#else
			UIFontDescriptor *descriptor = currentFont.fontDescriptor;
			bold = (descriptor.symbolicTraits & UIFontDescriptorTraitBold) == UIFontDescriptorTraitBold;
			italic = (descriptor.symbolicTraits & UIFontDescriptorTraitItalic) == UIFontDescriptorTraitItalic;
#endif
			NSNumber *oblique = dict[NSObliquenessAttributeName];
			if( oblique && [oblique floatValue] > 0. ) italic = YES;
			if( [dict[NSUnderlineStyleAttributeName] intValue] ) underline = YES;
		}

#if SYSTEM(MAC)
		if( backgroundColor && ! foregroundColor )
			foregroundColor = [NSColor colorWithCalibratedRed:0. green:0. blue:0. alpha:1.];

		if( ! [[foregroundColor colorSpaceName] isEqualToString:NSCalibratedRGBColorSpace] && ! [[foregroundColor colorSpaceName] isEqualToString:NSDeviceRGBColorSpace] )
			foregroundColor = [foregroundColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace]; // we need to convert to RGB space
#endif

		if( foregroundColor && ! [options[@"IgnoreFontColors"] boolValue] ) {
			char buffer[6];
			CGFloat red = 0., green = 0., blue = 0.;
			[foregroundColor getRed:&red green:&green blue:&blue alpha:NULL];

			unsigned short ircColor = colorRGBToMIRCColor( red * 255, green * 255, blue * 255 );

			snprintf( buffer, 6, "\003%d", ircColor );
			[ret appendBytes:buffer length:strlen( buffer )];

#if SYSTEM(MAC)
			if( ! [[backgroundColor colorSpaceName] isEqualToString:NSCalibratedRGBColorSpace] && ! [[backgroundColor colorSpaceName] isEqualToString:NSDeviceRGBColorSpace] )
				backgroundColor = [backgroundColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace]; // we need to convert to RGB space
#endif

			if( backgroundColor ) {
				[backgroundColor getRed:&red green:&green blue:&blue alpha:NULL];
				ircColor = colorRGBToMIRCColor( red * 255, green * 255, blue * 255 );

				snprintf( buffer, 6, ",%d", ircColor );
				[ret appendBytes:buffer length:strlen( buffer )];
			}
		}

		if( bold ) [ret appendBytes:"\002" length:1];
		if( italic ) [ret appendBytes:"\026" length:1];
		if( underline ) [ret appendBytes:"\037" length:1];

		NSData *data = nil;
		if( [link isKindOfClass:[NSURL class]] ) {
			data = [[link absoluteString] dataUsingEncoding:encoding allowLossyConversion:YES];
		} else if( [link isKindOfClass:[NSString class]] ) {
			data = [link dataUsingEncoding:encoding allowLossyConversion:YES];
		} else {
			NSString *text = [[self attributedSubstringFromRange:effectiveRange] string];
			data = [text dataUsingEncoding:encoding allowLossyConversion:YES];
		}

		[ret appendData:data];

		if( foregroundColor || bold || italic || underline )
			[ret appendBytes:"\017" length:1]; // reset the formatting only if we had formatting

		limitRange = NSMakeRange( NSMaxRange( effectiveRange ), NSMaxRange( limitRange ) - NSMaxRange( effectiveRange ) );
	}

	return ret;
}

#if SYSTEM(MAC)
- (NSData *) _CTCP2FormatWithOptions:(NSDictionary *) options {
	NSRange limitRange, effectiveRange;
	NSMutableData *ret = [[NSMutableData alloc] initWithCapacity:( self.length + 40 )];
	NSStringEncoding encoding = [[options objectForKey:@"StringEncoding"] unsignedLongValue];
	if( ! encoding ) encoding = NSISOLatin1StringEncoding;

	NSCharacterSet *nonASCIISet = [[NSCharacterSet characterSetWithRange:NSMakeRange( 0, 127 )] invertedSet];

	const char *ctcpEncoding = NULL;
	if( [[self string] rangeOfCharacterFromSet:nonASCIISet].location != NSNotFound ) {
		switch( encoding ) {
		case NSUTF8StringEncoding:
			ctcpEncoding = "U";
			break;
		case NSISOLatin1StringEncoding:
			ctcpEncoding = "1";
			break;
		case NSISOLatin2StringEncoding:
			ctcpEncoding = "2";
			break;
		case 0x80000203:
			ctcpEncoding = "3";
			break;
		case 0x80000204:
			ctcpEncoding = "4";
			break;
		case 0x80000205:
			ctcpEncoding = "5";
			break;
		case 0x80000206:
			ctcpEncoding = "6";
			break;
		case 0x80000207:
			ctcpEncoding = "7";
			break;
		case 0x80000208:
			ctcpEncoding = "8";
			break;
		case 0x80000209:
			ctcpEncoding = "9";
			break;
		case 0x8000020A:
			ctcpEncoding = "10";
			break;
		}
	}

	NSStringEncoding currentEncoding = NSASCIIStringEncoding;
	BOOL wasBold = NO, wasItalic = NO, wasUnderline = NO, wasStrikethrough = NO;
	NSColor *oldForeground = nil, *oldBackground = nil;
	id oldLink = nil;
	limitRange = NSMakeRange( 0, self.length );
	while( limitRange.length > 0 ) {
		NSDictionary *dict = [self attributesAtIndex:limitRange.location longestEffectiveRange:&effectiveRange inRange:limitRange];

		id link = dict[NSLinkAttributeName];

		if( ! ( link && oldLink && [link isEqual:oldLink] ) ) {
			NSColor *foregroundColor = nil, *backgroundColor = nil;
			if( ! [options[@"IgnoreFontColors"] boolValue] ) {
				foregroundColor = dict[NSForegroundColorAttributeName];
				backgroundColor = dict[NSBackgroundColorAttributeName];
			}

			BOOL bold = NO, italic = NO, underline = NO, strikethrough = NO;
			if( ! [options[@"IgnoreFontTraits"] boolValue] ) {
				NSFont *currentFont = dict[NSFontAttributeName];
				NSFontTraitMask traits = [[NSFontManager sharedFontManager] traitsOfFont:currentFont];
				if( traits & NSBoldFontMask ) bold = YES;
				if( traits & NSItalicFontMask ) italic = YES;
				NSNumber *oblique = dict[NSObliquenessAttributeName];
				if( oblique && [oblique floatValue] > 0. ) italic = YES;
				if( [dict[NSUnderlineStyleAttributeName] intValue] ) underline = YES;
				if( [dict[NSStrikethroughStyleAttributeName] intValue] ) strikethrough = YES;
			}

			NSString *foreColorString = nil, *backColorString = nil;
			// Check if both old and new colors exist, and if so, compare
			// Otherwise, compare the color pointers - at least one will be nil
			if( ( foregroundColor && oldForeground && ![foregroundColor isEqual:oldForeground] ) ||
				( foregroundColor != oldForeground ) ) {
				if( foregroundColor ) {
					foreColorString = [foregroundColor HTMLAttributeValue];
				} else {
					foreColorString = @".";
				}
			}

			if( ( backgroundColor && oldBackground && ![backgroundColor isEqual:oldBackground] ) ||
				( backgroundColor != oldBackground ) ) {
				if( backgroundColor ) {
					backColorString = [backgroundColor HTMLAttributeValue];
				} else {
					backColorString = @".";
				}
			}

			if( foreColorString || backColorString ) {
				[ret appendBytes:"\006C" length:2];

				// If both foreground and background colors are unset, don't bother
				// with anything since .. is assumed
				if( ! ( foregroundColor == nil && backgroundColor == nil ) ) {
					if( foreColorString ) {
						const char *str = [foreColorString UTF8String];
						[ret appendBytes:str length:strlen( str )];
					} else {
						[ret appendBytes:"-" length:1];
					}

					if( backColorString ) {
						const char *str = [backColorString UTF8String];
						[ret appendBytes:str length:strlen( str )];
					} // If no background, don't bother with "-" since it's assumed
				}

				[ret appendBytes:"\006" length:1];
			}

			if( bold != wasBold )
				[ret appendBytes:( bold ? "\006B\006" : "\006B-\006" ) length:( bold ? 3 : 4 )];
			if( italic != wasItalic )
				[ret appendBytes:( italic ? "\006I\006" : "\006I-\006" ) length:( italic ? 3 : 4 )];
			if( underline != wasUnderline )
				[ret appendBytes:( underline ? "\006U\006" : "\006U-\006" ) length:( underline ? 3 : 4 )];
			if( strikethrough != wasStrikethrough )
				[ret appendBytes:( strikethrough ? "\006S\006" : "\006S-\006" ) length:( strikethrough ? 3 : 4 )];

			NSString *text;
			if( [link isKindOfClass:[NSURL class]] || [link isKindOfClass:[NSString class]] ) {
				text = [link description];
				[ret appendBytes:"\006L\006" length:3];
			} else {
				text = [[self string] substringWithRange:effectiveRange];
				link = nil;
			}

			NSData *data = [text dataUsingEncoding:currentEncoding allowLossyConversion:NO];
			if( ! data && currentEncoding == NSASCIIStringEncoding && encoding != NSASCIIStringEncoding ) {
				// Ok, upgrade to declared encoding
				currentEncoding = encoding;
				data = [text dataUsingEncoding:currentEncoding allowLossyConversion:NO];
				if( data != nil && ctcpEncoding ) {
					[ret appendBytes:"\006E" length:2];
					[ret appendBytes:ctcpEncoding length:strlen( ctcpEncoding )];
					[ret appendBytes:"\006" length:1];
				}
			}
			if( ! data ) {
				if( currentEncoding == NSUTF8StringEncoding ) {
					// It shouldn't have failed, but I want to cover all the bases
					data = [text dataUsingEncoding:currentEncoding allowLossyConversion:YES];
				} else {
					// Time to upgrade
					currentEncoding = NSUTF8StringEncoding;
					data = [text dataUsingEncoding:currentEncoding allowLossyConversion:YES];
					[ret appendBytes:"\006EU\006" length:4];
				}
			}
			if( data ) [ret appendData:data];

			wasBold = bold; wasItalic = italic; wasUnderline = underline; wasStrikethrough = strikethrough;
			oldForeground = foregroundColor; oldBackground = backgroundColor; oldLink = link;

		} // ![link isEqual:oldLink]

		limitRange = NSMakeRange( NSMaxRange( effectiveRange ), NSMaxRange( limitRange ) - NSMaxRange( effectiveRange ) );
	}

	return ret;
}
#endif

- (NSData *) chatFormatWithOptions:(NSDictionary *) options {
	NSString *format = options[@"FormatType"];

#if SYSTEM(MAC)
	if( [format isEqualToString:NSChatCTCPTwoFormatType] ) return [self _CTCP2FormatWithOptions:options];
	else if( [format isEqualToString:NSChatWindowsIRCFormatType] ) return [self _mIRCFormatWithOptions:options];
#else
	if( [format isEqualToString:NSChatWindowsIRCFormatType] ) return [self _mIRCFormatWithOptions:options];
#endif

	// No formatting.
	NSMutableData *ret = [NSMutableData data];
	NSStringEncoding encoding = [options[@"StringEncoding"] unsignedLongValue];
	if( ! encoding ) encoding = NSISOLatin1StringEncoding;

	NSData *data = [[self string] dataUsingEncoding:encoding allowLossyConversion:YES];
	if( data ) [ret appendData:data];

	return ret;
}

- (NSAttributedString *) cq_stringByRemovingCharactersInSet:(NSCharacterSet *) set {
	NSMutableAttributedString *mutableStorage = [self mutableCopy];
	NSRange range = [mutableStorage.string rangeOfCharacterFromSet:set];
	while (range.location != NSNotFound) {
		[mutableStorage replaceCharactersInRange:range withString:@""];
		range = [mutableStorage.string rangeOfCharacterFromSet:set];
	}

	return [mutableStorage copy];
}

- (NSAttributedString *) attributedSubstringFromIndex:(NSUInteger) index {
	NSUInteger length = self.string.length;
	if (length == 0) return [self copy];
	return [self attributedSubstringFromRange:NSMakeRange(index, length - index)];
}

- (NSArray <NSAttributedString *> *) cq_componentsSeparatedByCharactersInSet:(NSCharacterSet *) characterSet {
	NSParameterAssert(characterSet);

	NSArray <NSString *> *stringComponentsSeparatedByCharactersInSet = [self.string componentsSeparatedByCharactersInSet:characterSet];
	NSMutableArray <NSAttributedString *> *componentsSeparatedByCharactersInSet = [NSMutableArray array];
	NSUInteger currentIndex = 0;
	for (NSString *string in stringComponentsSeparatedByCharactersInSet) {
		[componentsSeparatedByCharactersInSet addObject:[self attributedSubstringFromRange:NSMakeRange(currentIndex, string.length)]];
		currentIndex += string.length;
	}

	return [componentsSeparatedByCharactersInSet copy];
}

- (NSAttributedString *) cq_stringByTrimmingCharactersInSet:(NSCharacterSet *) characterSet {
	NSString *string = self.string;

	NSUInteger startIndexToRemove = 0;
	for ( ; startIndexToRemove < string.length && [characterSet characterIsMember:[string characterAtIndex:startIndexToRemove]]; startIndexToRemove++) ;
	if (startIndexToRemove == string.length) return [[NSAttributedString alloc] initWithString:@""];

	NSUInteger endIndexToRemove = string.length - 1;
	for ( ; endIndexToRemove > 0 && [characterSet characterIsMember:[string characterAtIndex:endIndexToRemove]]; endIndexToRemove--) ;

	return [self attributedSubstringFromRange:NSMakeRange(startIndexToRemove, string.length - startIndexToRemove - (string.length - (endIndexToRemove + 1)))];
}
@end

NS_ASSUME_NONNULL_END
