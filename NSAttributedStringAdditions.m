#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "NSAttributedStringAdditions.h"
#import "NSColorAdditions.h"
#import "NSStringAdditions.h"

static const int mIRCColors[][3] = {
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
	{ 0xd6, 0xd6, 0xd6 }   /* 15) light grey */
};

static const int CTCPColors[][3] = {
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

static int colorRGBToMIRCColor( unsigned int red, unsigned int green, unsigned int blue ) {
	int distance = 1000, color = 1, i = 0, o = 0;
	for( i = 0; i < 16; i++ ) {
		o = abs( red - mIRCColors[i][0] ) +
		abs( green - mIRCColors[i][1] ) +
		abs( blue - mIRCColors[i][2] );
		if( o < distance ) {
			color = i;
			distance = o;
		}
	}
	return color;
}

static NSConditionLock *renderingFragmentLock = nil;
static WebView *fragmentWebView = nil;

@implementation NSAttributedString (NSAttributedStringHTMLAdditions)
+ (id) attributedStringWithHTMLFragment:(NSString *) fragment baseURL:(NSURL *) url {
	extern NSConditionLock *renderingFragmentLock;
	extern WebView *fragmentWebView;
	NSMutableAttributedString *result = nil;

	NSParameterAssert( fragment != nil );

	if( NSAppKitVersionNumber >= 700. ) {
		NSString *render = [NSString stringWithFormat:@"<font color=\"#01fe02\">%@</font>", fragment];
		result = [[[NSMutableAttributedString alloc] initWithHTML:[render dataUsingEncoding:NSUTF8StringEncoding] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:1], @"UseWebKit", @"utf-8", @"TextEncodingName", url, @"BaseURL", nil] documentAttributes:NULL] autorelease];
	} else {
		if( ! renderingFragmentLock )
			renderingFragmentLock = [[NSConditionLock alloc] initWithCondition:2];

		if( [renderingFragmentLock lockWhenCondition:2 beforeDate:[NSDate dateWithTimeIntervalSinceNow:2.]] ) { // wait until any other call to this method finishes; timesout after 2 seconds waiting
			[renderingFragmentLock unlockWithCondition:0];

			[NSThread detachNewThreadSelector:@selector( renderHTMLFragment: ) toTarget:self withObject:[NSDictionary dictionaryWithObjectsAndKeys:fragment, @"fragment", url, @"url", nil]];

			if( [renderingFragmentLock lockWhenCondition:1 beforeDate:[NSDate dateWithTimeIntervalSinceNow:3.]] ) { // wait until the rendering is done; timeouts in 3 seconds
				result = [[[(id <WebDocumentText>)[[[fragmentWebView mainFrame] frameView] documentView] attributedString] mutableCopy] autorelease];
				[renderingFragmentLock unlockWithCondition:2]; // we are done, safe for relase WebView
			}
		}

		if( ! result ) {
			NSString *render = [NSString stringWithFormat:@"<html><head><meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" /></head><body><font color=\"#01fe02\">%@</font></body></html>", fragment];
			result = [[[NSMutableAttributedString alloc] initWithHTML:[render dataUsingEncoding:NSUTF8StringEncoding] baseURL:url documentAttributes:NULL] autorelease];
		}
	}

	NSRange limitRange, effectiveRange;
	limitRange = NSMakeRange( 0, [result length] );
	while( limitRange.length > 0 ) {
		NSColor *color = [result attribute:NSForegroundColorAttributeName atIndex:limitRange.location longestEffectiveRange:&effectiveRange inRange:limitRange];
		if( [[color colorSpaceName] isEqualToString:NSCalibratedRGBColorSpace] && [[color HTMLAttributeValue] isEqualToString:@"#01fe02"] )
			[result removeAttribute:NSForegroundColorAttributeName range:effectiveRange];
		limitRange = NSMakeRange( NSMaxRange( effectiveRange ), NSMaxRange( limitRange ) - NSMaxRange( effectiveRange ) );
	}

	return result;
}

+ (void) renderHTMLFragment:(NSDictionary *) info {
	extern WebView *fragmentWebView;
	extern NSConditionLock *renderingFragmentLock;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	[renderingFragmentLock lockWhenCondition:0]; // start the rendering, makes parent thread block

	[NSThread setThreadPriority:1.0];

	NSString *fragment = [info objectForKey:@"fragment"];
	NSURL *url = [info objectForKey:@"url"];

	if( ! fragmentWebView ) fragmentWebView = [[WebView alloc] initWithFrame:NSMakeRect( 0., 0., 2000., 100. ) frameName:nil groupName:nil];
	[fragmentWebView setFrameLoadDelegate:self];
	[[fragmentWebView mainFrame] loadHTMLString:[NSString stringWithFormat:@"<html><head><meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" /></head><body><font color=\"#01fe02\">%@</font></body></html>", fragment] baseURL:url];

	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];

	[renderingFragmentLock lockWhenCondition:2]; // wait until it is safe to release
	[renderingFragmentLock unlockWithCondition:2];

	[pool release];
}

+ (void) webView:(WebView *) sender didFinishLoadForFrame:(WebFrame *) frame {
	extern NSConditionLock *renderingFragmentLock;
	[renderingFragmentLock unlockWithCondition:1]; // rendering is complete
	[sender setFrameLoadDelegate:nil];
}

- (NSString *) HTMLFormatWithOptions:(NSDictionary *) options {
	NSRange limitRange, effectiveRange;
	NSMutableString *ret = [NSMutableString string];

	if( [[options objectForKey:@"FullDocument"] boolValue] ) {
		[ret appendString:@"<html><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\"></head><body>"];
	}

	limitRange = NSMakeRange( 0, [self length] );
	while( limitRange.length > 0 ) {
		NSDictionary *dict = [self attributesAtIndex:limitRange.location longestEffectiveRange:&effectiveRange inRange:limitRange];

		id link = [dict objectForKey:NSLinkAttributeName];
		NSFont *currentFont = [dict objectForKey:NSFontAttributeName];
		NSColor *foregoundColor = [dict objectForKey:NSForegroundColorAttributeName];
		NSColor *backgroundColor = [dict objectForKey:NSBackgroundColorAttributeName];
		NSString *htmlStart = [dict objectForKey:@"XHTMLStart"];
		NSString *htmlEnd = [dict objectForKey:@"XHTMLEnd"];
		NSSet *classes = [dict objectForKey:@"CSSClasses"];
		BOOL bold = NO, italic = NO, underline = NO, strikethrough = NO;

		NSMutableString *spanString = [NSMutableString stringWithString:@"<span"];
		NSMutableString *styleString = [NSMutableString string];

		if( foregoundColor && ! [[options objectForKey:@"IgnoreFontColors"] boolValue] ) {
			[styleString appendFormat:@"color: %@", [foregoundColor CSSAttributeValue]];
		}

		if( backgroundColor && ! [[options objectForKey:@"IgnoreFontColors"] boolValue] ) {
			if( [styleString length] ) [styleString appendString:@"; "];
			[styleString appendFormat:@"background-color: %@", [backgroundColor CSSAttributeValue]];
		}

		if( ! [[options objectForKey:@"IgnoreFonts"] boolValue] ) {
			if( [styleString length] ) [styleString appendString:@"; "];
			NSString *family = [currentFont familyName];
			if( [family rangeOfString:@" "].location != NSNotFound )
				family = [NSString stringWithFormat:@"'%@'", family];
			[styleString appendFormat:@"font-family: %@", family];
		}

		if( ! [[options objectForKey:@"IgnoreFontSizes"] boolValue] ) {
			if( [styleString length] ) [styleString appendString:@"; "];
			[styleString appendFormat:@"font-size: %.1fpt", [currentFont pointSize]];
		}

		if( ! [[options objectForKey:@"IgnoreFontTraits"] boolValue] ) {
			int traits = [[NSFontManager sharedFontManager] traitsOfFont:currentFont];
			if( traits & NSBoldFontMask ) bold = YES;
			if( traits & NSItalicFontMask ) italic = YES;
			if( [[dict objectForKey:NSUnderlineStyleAttributeName] intValue] ) underline = YES;
			if( [[dict objectForKey:NSStrikethroughStyleAttributeName] intValue] ) strikethrough = YES;
		}

		if( [styleString length] ) [spanString appendFormat:@" style=\"%@\"", styleString];
		if( [classes count] ) [spanString appendFormat:@" class=\"%@\"", [[classes allObjects] componentsJoinedByString:@" "]];
		[spanString appendString:@">"];

		if( [classes count] || [styleString length] ) [ret appendString:spanString];
		if( bold ) [ret appendString:@"<b>"];
		if( italic ) [ret appendString:@"<i>"];
		if( underline ) [ret appendString:@"<u>"];
		if( strikethrough ) [ret appendString:@"<s>"];
		if( [htmlStart length] ) [ret appendString:htmlStart];
		if( link ) [ret appendFormat:@"<a href=\"%@\">", [link stringByEncodingXMLSpecialCharactersAsEntities]];

		[ret appendString:[[[self attributedSubstringFromRange:effectiveRange] string] stringByEncodingXMLSpecialCharactersAsEntities]];

		if( link ) [ret appendString:@"</a>"];
		if( [htmlEnd length] ) [ret appendString:htmlEnd];
		if( strikethrough ) [ret appendString:@"</s>"];
		if( underline ) [ret appendString:@"</u>"];
		if( italic ) [ret appendString:@"</i>"];
		if( bold ) [ret appendString:@"</b>"];
		if( [classes count] || [styleString length] ) [ret appendString:@"</span>"];

		limitRange = NSMakeRange( NSMaxRange( effectiveRange ), NSMaxRange( limitRange ) - NSMaxRange( effectiveRange ) );
	}

	if( [[options objectForKey:@"FullDocument"] boolValue] )
		[ret appendString: @"</body></html>"];

	return [[ret retain] autorelease];
}

#pragma mark -

+ (id) attributedStringWithIRCFormat:(NSData *) data options:(NSDictionary *) options {
	return [[[self alloc] initWithIRCFormat:data options:options] autorelease];
}

- (id) initWithIRCFormat:(NSData *) data options:(NSDictionary *) options {
	NSStringEncoding encoding = [[options objectForKey:@"StringEncoding"] unsignedIntValue];
	if( ! encoding ) encoding = NSUTF8StringEncoding;

	NSString *message = [[[NSString alloc] initWithData:data encoding:encoding] autorelease];
	if( ! message ) {
		[self autorelease];
		return nil;
	}

	NSCharacterSet *formatCharacters = [NSCharacterSet characterSetWithCharactersInString:@"\002\003\006\026\037\017"];
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

	NSFont *baseFont = [options objectForKey:@"BaseFont"];
	if( ! baseFont ) baseFont = [NSFont userFontOfSize:12.];
	[attributes setObject:baseFont forKey:NSFontAttributeName];

	// if the message dosen't have any formatting chars just init as a plain string and return quickly
	if( [message rangeOfCharacterFromSet:formatCharacters].location == NSNotFound )
		return ( self = [self initWithString:message attributes:attributes] );

	NSMutableAttributedString *ret = [[NSMutableAttributedString new] autorelease];
	NSScanner *scanner = [NSScanner scannerWithString:message];
	[scanner setCharactersToBeSkipped:nil]; // don't skip leading whitespace!

	char boldStack = 0, italicStack = 0, underlineStack = 0, strikeStack = 0;

	while( ! [scanner isAtEnd] ) {
		NSString *attribs = nil;
		unsigned int location = [scanner scanLocation];
 		[scanner scanCharactersFromSet:formatCharacters intoString:&attribs];

		unsigned int i = 0;
		for( i = 0; i < [attribs length]; i++, location++ ) {
			switch( [attribs characterAtIndex:i] ) {
			case '\017': // reset all
				boldStack = italicStack = underlineStack = strikeStack = 0;
				NSFont *font = [[NSFontManager sharedFontManager] convertFont:[attributes objectForKey:NSFontAttributeName] toNotHaveTrait:( NSBoldFontMask | NSItalicFontMask )];
				if( font ) [attributes setObject:font forKey:NSFontAttributeName];
				[attributes removeObjectForKey:NSStrikethroughStyleAttributeName];
				[attributes removeObjectForKey:NSUnderlineStyleAttributeName];
				[attributes removeObjectForKey:NSForegroundColorAttributeName];
				[attributes removeObjectForKey:NSBackgroundColorAttributeName];
				break;
			case '\002': // toggle bold
				if( [[options objectForKey:@"IgnoreFontTraits"] boolValue] ) break;
				boldStack = ! boldStack;
				if( boldStack ) {
					NSFont *font = [[NSFontManager sharedFontManager] convertFont:[attributes objectForKey:NSFontAttributeName] toHaveTrait:NSBoldFontMask];
					if( font ) [attributes setObject:font forKey:NSFontAttributeName];
				} else {
					NSFont *font = [[NSFontManager sharedFontManager] convertFont:[attributes objectForKey:NSFontAttributeName] toNotHaveTrait:NSBoldFontMask];
					if( font ) [attributes setObject:font forKey:NSFontAttributeName];
				}
				break;
			case '\026': // toggle italic
				if( [[options objectForKey:@"IgnoreFontTraits"] boolValue] ) break;
				italicStack = ! italicStack;
				if( italicStack ) {
					NSFont *font = [[NSFontManager sharedFontManager] convertFont:[attributes objectForKey:NSFontAttributeName] toHaveTrait:NSItalicFontMask];
					if( font ) [attributes setObject:font forKey:NSFontAttributeName];
				} else {
					NSFont *font = [[NSFontManager sharedFontManager] convertFont:[attributes objectForKey:NSFontAttributeName] toNotHaveTrait:NSItalicFontMask];
					if( font ) [attributes setObject:font forKey:NSFontAttributeName];
				}
				break;
			case '\037': // toggle underline
				if( [[options objectForKey:@"IgnoreFontTraits"] boolValue] ) break;
				underlineStack = ! underlineStack;
				if( underlineStack ) [attributes setObject:[NSNumber numberWithInt:1] forKey:NSUnderlineStyleAttributeName];
				else [attributes removeObjectForKey:NSUnderlineStyleAttributeName];
				break;
			case '\003': // color
				if( [[options objectForKey:@"IgnoreFontColors"] boolValue] ) break;
				if( [message length] > ( location + 1 ) ) {
					[scanner setScanLocation:( location + 1 )];

					unsigned int fcolor = 0;
					if( [scanner scanInt:&fcolor] ) {
						fcolor %= 16;

						NSColor *foregroundColor = [NSColor colorWithCalibratedRed:( (float) mIRCColors[fcolor][0] / 255. ) green:( (float) mIRCColors[fcolor][1] / 255. ) blue:( (float) mIRCColors[fcolor][2] / 255. ) alpha:1.];
						if( foregroundColor ) [attributes setObject:foregroundColor forKey:NSForegroundColorAttributeName];

						unsigned int bcolor = 0;
						if( [scanner scanString:@"," intoString:NULL] && [scanner scanInt:&bcolor] && bcolor != 99 ) {
							bcolor %= 16;
							NSColor *backgroundColor = [NSColor colorWithCalibratedRed:( (float) mIRCColors[bcolor][0] / 255. ) green:( (float) mIRCColors[bcolor][1] / 255. ) blue:( (float) mIRCColors[bcolor][2] / 255. ) alpha:1.];
							if( backgroundColor ) [attributes setObject:backgroundColor forKey:NSBackgroundColorAttributeName];
						}
					} else { // no color, reset both colors
						[attributes removeObjectForKey:NSForegroundColorAttributeName];
						[attributes removeObjectForKey:NSBackgroundColorAttributeName];
					}
				}
				break;
			case '\006': // ctcp 2 formatting (http://www.lag.net/~robey/ctcp/ctcp2.2.txt)
				if( [message length] > ( location + 2 ) ) {
					BOOL off = NO;

					[scanner setScanLocation:( location + 2 )];

					switch( [message characterAtIndex:( location + 1 )] ) {
					case 'B': // bold
						if( [[options objectForKey:@"IgnoreFontTraits"] boolValue] ) break;
						if( [scanner scanString:@"-" intoString:NULL] ) {
							if( boldStack >= 1 ) boldStack--;
							off = YES;
						} else { // on is the default
							[scanner scanString:@"+" intoString:NULL];
							boldStack++;
						}

						if( boldStack == 1 && ! off ) {
							NSFont *font = [[NSFontManager sharedFontManager] convertFont:[attributes objectForKey:NSFontAttributeName] toHaveTrait:NSBoldFontMask];
							if( font ) [attributes setObject:font forKey:NSFontAttributeName];
						} else if( ! boldStack ) {
							NSFont *font = [[NSFontManager sharedFontManager] convertFont:[attributes objectForKey:NSFontAttributeName] toNotHaveTrait:NSBoldFontMask];
							if( font ) [attributes setObject:font forKey:NSFontAttributeName];
						}
						break;
					case 'I': // italic
						if( [[options objectForKey:@"IgnoreFontTraits"] boolValue] ) break;
						if( [scanner scanString:@"-" intoString:NULL] ) {
							if( italicStack >= 1 ) italicStack--;
							off = YES;
						} else { // on is the default
							[scanner scanString:@"+" intoString:NULL];
							italicStack++;
						}

						if( italicStack == 1 && ! off ) {
							NSFont *font = [[NSFontManager sharedFontManager] convertFont:[attributes objectForKey:NSFontAttributeName] toHaveTrait:NSItalicFontMask];
							if( font ) [attributes setObject:font forKey:NSFontAttributeName];
						} else if( ! italicStack ) {
							NSFont *font = [[NSFontManager sharedFontManager] convertFont:[attributes objectForKey:NSFontAttributeName] toNotHaveTrait:NSItalicFontMask];
							if( font ) [attributes setObject:font forKey:NSFontAttributeName];
						}
						break;
					case 'U': // underline
						if( [[options objectForKey:@"IgnoreFontTraits"] boolValue] ) break;
						if( [scanner scanString:@"-" intoString:NULL] ) {
							if( underlineStack >= 1 ) underlineStack--;
							off = YES;
						} else { // on is the default
							[scanner scanString:@"+" intoString:NULL];
							underlineStack++;
						}

						if( underlineStack == 1 && ! off ) {
							[attributes setObject:[NSNumber numberWithInt:1] forKey:NSUnderlineStyleAttributeName];
						} else if( ! underlineStack ) {
							[attributes removeObjectForKey:NSUnderlineStyleAttributeName];
						}
						break;
					case 'S': // strikethrough
						if( [[options objectForKey:@"IgnoreFontTraits"] boolValue] ) break;
						if( [scanner scanString:@"-" intoString:NULL] ) {
							if( strikeStack >= 1 ) strikeStack--;
							off = YES;
						} else { // on is the default
							[scanner scanString:@"+" intoString:NULL];
							strikeStack++;
						}

						if( strikeStack == 1 && ! off ) {
							[attributes setObject:[NSNumber numberWithInt:1] forKey:NSStrikethroughStyleAttributeName];
						} else if( ! strikeStack ) {
							[attributes removeObjectForKey:NSStrikethroughStyleAttributeName];
						}
						break;
					case 'C': // color
						if( [[options objectForKey:@"IgnoreFontColors"] boolValue] ) break;
						if( [message characterAtIndex:[scanner scanLocation]] == '\006' ) { // reset colors
							[attributes removeObjectForKey:NSForegroundColorAttributeName];
							[attributes removeObjectForKey:NSBackgroundColorAttributeName];
							break;
						}
						// scan for foreground color
						if( [scanner scanString:@"#" intoString:NULL] ) { // rgb hex color
							NSString *hexColor = nil;
							if( [message length] > [scanner scanLocation] + 6 ) {
								hexColor = [message substringWithRange:NSMakeRange( [scanner scanLocation], 6 )];
								NSColor *foregroundColor = [NSColor colorWithHTMLAttributeValue:hexColor];
								if( foregroundColor ) [attributes setObject:foregroundColor forKey:NSForegroundColorAttributeName];
								[scanner setScanLocation:( [scanner scanLocation] + 6 )];
							}
						} else if( isxdigit( [message characterAtIndex:[scanner scanLocation]] ) ) { // indexed color
							unsigned int index = toupper( [message characterAtIndex:[scanner scanLocation]] );
							if( index >= 'A' ) index -= ( 'A' - '9' - 1 );
							index -= '0';
							if( index > 15 ) break;
							NSColor *foregroundColor = [NSColor colorWithCalibratedRed:( (float) CTCPColors[index][0] / 255. ) green:( (float) CTCPColors[index][1] / 255. ) blue:( (float) CTCPColors[index][2] / 255. ) alpha:1.];
							if( foregroundColor ) [attributes setObject:foregroundColor forKey:NSForegroundColorAttributeName];
							[scanner setScanLocation:( [scanner scanLocation] + 1 )];
						} else if( [scanner scanString:@"." intoString:NULL] ) { // reset the foreground color
							[attributes removeObjectForKey:NSForegroundColorAttributeName];
						} else [scanner scanString:@"-" intoString:NULL]; // skip the foreground color
						// scan for background color
						if( [scanner scanString:@"#" intoString:NULL] ) { // rgb hex color
							NSString *hexColor = nil;
							if( [message length] > [scanner scanLocation] + 6 ) {
								hexColor = [message substringWithRange:NSMakeRange( [scanner scanLocation], 6 )];
								NSColor *backgroundColor = [NSColor colorWithHTMLAttributeValue:hexColor];
								if( backgroundColor ) [attributes setObject:backgroundColor forKey:NSBackgroundColorAttributeName];
								[scanner setScanLocation:( [scanner scanLocation] + 6 )];
							}
						} else if( isxdigit( [message characterAtIndex:[scanner scanLocation]] ) ) { // indexed color
							unsigned int index = toupper( [message characterAtIndex:[scanner scanLocation]] );
							if( index >= 'A' ) index -= ( 'A' - '9' - 1 );
							index -= '0';
							if( index > 15 ) break;
							NSColor *backgroundColor = [NSColor colorWithCalibratedRed:( (float) CTCPColors[index][0] / 255. ) green:( (float) CTCPColors[index][1] / 255. ) blue:( (float) CTCPColors[index][2] / 255. ) alpha:1.];
							if( backgroundColor ) [attributes setObject:backgroundColor forKey:NSBackgroundColorAttributeName];
							[scanner setScanLocation:( [scanner scanLocation] + 1 )];
						} else if( [scanner scanString:@"." intoString:NULL] ) { // reset the background color
							[attributes removeObjectForKey:NSBackgroundColorAttributeName];
						} else [scanner scanString:@"-" intoString:NULL]; // skip the background color
					case 'F': // font size
					case 'E': // encoding
					case 'P': // spacing
						// not supported yet
						break;
					case 'N': // normal (reset)
						boldStack = italicStack = underlineStack = strikeStack = 0;
						NSFont *font = [[NSFontManager sharedFontManager] convertFont:[attributes objectForKey:NSFontAttributeName] toNotHaveTrait:( NSBoldFontMask | NSItalicFontMask )];
						if( font ) [attributes setObject:font forKey:NSFontAttributeName];
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

		NSString *text = nil;
 		[scanner scanUpToCharactersFromSet:formatCharacters intoString:&text];
		if( [text length] ) {
			NSAttributedString *new = [[NSAttributedString alloc] initWithString:text attributes:attributes];
			[ret appendAttributedString:new];
			[new release];
		}
	}

	return ( self = [self initWithAttributedString:ret] );
}

- (NSData *) _mIRCFormatWithOptions:(NSDictionary *) options {
	NSRange limitRange, effectiveRange;
	NSMutableData *ret = [NSMutableData data];
	NSStringEncoding encoding = [[options objectForKey:@"StringEncoding"] unsignedIntValue];
	if( ! encoding ) encoding = NSUTF8StringEncoding;

	limitRange = NSMakeRange( 0, [self length] );
	while( limitRange.length > 0 ) {
		NSDictionary *dict = [self attributesAtIndex:limitRange.location longestEffectiveRange:&effectiveRange inRange:limitRange];

		id link = [dict objectForKey:NSLinkAttributeName];
		NSFont *currentFont = [dict objectForKey:NSFontAttributeName];
		NSColor *foregroundColor = [dict objectForKey:NSForegroundColorAttributeName];
		NSColor *backgroundColor = [dict objectForKey:NSBackgroundColorAttributeName];
		BOOL bold = NO, italic = NO, underline = NO;

		if( ! [[options objectForKey:@"IgnoreFontTraits"] boolValue] ) {
			int traits = [[NSFontManager sharedFontManager] traitsOfFont:currentFont];
			if( traits & NSBoldFontMask ) bold = YES;
			if( traits & NSItalicFontMask ) italic = YES;
			if( [[dict objectForKey:NSUnderlineStyleAttributeName] intValue] ) underline = YES;
		}

		if( backgroundColor && ! foregroundColor )
			foregroundColor = [NSColor colorWithCalibratedRed:0. green:0. blue:0. alpha:1.];

		if( foregroundColor && ! [[options objectForKey:@"IgnoreFontColors"] boolValue] ) {
			char buffer[6];
			float red = 0., green = 0., blue = 0.;
			[foregroundColor getRed:&red green:&green blue:&blue alpha:NULL];

			int ircColor = colorRGBToMIRCColor( red * 255, green * 255, blue * 255 );

			sprintf( buffer, "\003%02d", ircColor );
			[ret appendBytes:buffer length:strlen( buffer )];

			if( backgroundColor ) {
				[backgroundColor getRed:&red green:&green blue:&blue alpha:NULL];
				ircColor = colorRGBToMIRCColor( red * 255, green * 255, blue * 255 );

				sprintf( buffer, ",%02d", ircColor );
				[ret appendBytes:buffer length:strlen( buffer )];
			}
		}

		if( bold ) [ret appendBytes:"\002" length:1];
		if( italic ) [ret appendBytes:"\026" length:1];
		if( underline ) [ret appendBytes:"\037" length:1];

		NSData *data = nil;
		if( [link isKindOfClass:[NSURL class]] ) data = [[link absoluteString] dataUsingEncoding:encoding allowLossyConversion:YES];
		else if( [link isKindOfClass:[NSString class]] ) data = [link dataUsingEncoding:encoding allowLossyConversion:YES];
		else {
			NSString *text = [[self attributedSubstringFromRange:effectiveRange] string];
			data = [text dataUsingEncoding:encoding allowLossyConversion:YES];
		}

		[ret appendData:data];

		if( foregroundColor || bold || italic || underline )
			[ret appendBytes:"\017" length:1]; // reset the formatting only if we had formatting

		limitRange = NSMakeRange( NSMaxRange( effectiveRange ), NSMaxRange( limitRange ) - NSMaxRange( effectiveRange ) );
	}

	if( [[options objectForKey:@"NullTerminatedReturn"] boolValue] )
		[ret appendBytes:"\0" length:1];

	return [[ret retain] autorelease];
}

- (NSData *) _CTCP2FormatWithOptions:(NSDictionary *) options {
	return nil;
}

- (NSData *) IRCFormatWithOptions:(NSDictionary *) options {
	if( [[options objectForKey:@"FormatType"] isEqualToString:@"CTCP2"] )
		return [self _CTCP2FormatWithOptions:options];
	else return [self _mIRCFormatWithOptions:options];
}
@end