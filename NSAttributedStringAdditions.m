#import "NSAttributedStringAdditions.h"
#import <Cocoa/Cocoa.h>
#import "HTMLDisplay.h"

@implementation NSAttributedString (NSAttributedStringHTMLAdditions)
+ (NSDictionary *) linkAttributesForTarget:(NSString *) link {
	return [self linkAttributesForTarget:link usingColor:nil withUnderline:YES];
}

+ (NSDictionary *) linkAttributesForTarget:(NSString *) link usingColor:(NSColor *) color withUnderline:(BOOL) underline {
	NSMutableDictionary *d = [NSMutableDictionary dictionary];
	NSParameterAssert( link != nil );
	[d setObject:link forKey:NSLinkAttributeName];
	if( underline ) [d setObject:[NSNumber numberWithInt:NSSingleUnderlineStyle] forKey:NSUnderlineStyleAttributeName];
	[d setObject:( color ? color : [NSColor blueColor] ) forKey:NSForegroundColorAttributeName];
	return d;
}

+ (NSAttributedString *) attributedStringWithHTML:(NSData *) html usingEncoding:(NSStringEncoding) encoding documentAttributes:(NSDictionary **) dict {
	CFStringEncoding enc = kCFStringEncodingUTF8;
	enc = CFStringConvertNSStringEncodingToEncoding( encoding );
	return [[[HTMLDocument attributedStringWithHTML:html useEncoding:enc documentAttributes:dict] retain] autorelease];
}

- (NSData *) HTMLWithOptions:(NSDictionary *) options usingEncoding:(NSStringEncoding) encoding allowLossyConversion:(BOOL) loss {
	NSRange limitRange, effectiveRange;
	NSMutableString *out = nil;
	NSMutableData *ret = nil;
	NSColor *backColor = nil, *foreColor = nil;
	NSFont *baseFont = [NSFont userFontOfSize:12.];

	out = [NSMutableString string];

	if( ! foreColor ) foreColor = [NSColor textColor];
	if( ! backColor ) backColor = [NSColor textBackgroundColor];

	if( [[options objectForKey:@"NSHTMLFullDocument"] boolValue] ) {
		CFStringEncoding enc = CFStringConvertNSStringEncodingToEncoding( encoding );
		[out appendFormat:@"<html><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=%@\"></head><body bgcolor=\"%@\">", [NSString mimeCharsetTagFromStringEncoding:enc], [backColor htmlAttributeValue]];
	}

	limitRange = NSMakeRange( 0, [self length] );
	while( limitRange.length > 0 ) {
		BOOL bFlag = NO;
		BOOL iFlag = NO;
		BOOL uFlag = NO;
		BOOL fontFlag = NO;
		BOOL linkFlag = NO;
		NSMutableString *substr = nil;
		NSMutableString *fontstr = nil;
		NSMutableDictionary *dict = [[[self attributesAtIndex:limitRange.location longestEffectiveRange:&effectiveRange inRange:limitRange] mutableCopy] autorelease];
		NSString *link = [dict objectForKey:NSLinkAttributeName];
		NSFont *curFont = [dict objectForKey:NSFontAttributeName];

		if( link ) {
			linkFlag = YES;
			[dict removeObjectsForKeys:[[NSAttributedString linkAttributesForTarget:link] allKeys]];
		}

		if( ! [[options objectForKey:@"NSHTMLIgnoreFonts"] boolValue] ) {
			NSColor *fColor = [dict objectForKey:NSForegroundColorAttributeName];
			NSColor *bColor = [dict objectForKey:NSBackgroundColorAttributeName];

			fontstr = [NSMutableString stringWithString:@"<font"];

			if( fColor && ! [[options objectForKey:@"NSHTMLIgnoreFontColors"] boolValue] ) {
				[fontstr appendFormat:@" color=\"%@\"", [fColor htmlAttributeValue]];
				fontFlag = YES;
			}
			if( bColor && ! [[options objectForKey:@"NSHTMLIgnoreFontColors"] boolValue] ) {
				[fontstr appendFormat:@" style=\"background-color: %@\"", [bColor htmlAttributeValue]];
				fontFlag = YES;
			}
			if( ! [[options objectForKey:@"NSHTMLIgnoreFontSizes"] boolValue] && [curFont pointSize] != [baseFont pointSize] ) {
				float r = [curFont pointSize] / [baseFont pointSize];
				[fontstr appendString: @" size="];
				if( r < 0.8 ) [fontstr appendString: @"\"1\""];
				else if( r < 0.9 ) [fontstr appendString: @"\"2\""];
				else if( r < 1.1 ) [fontstr appendString: @"\"3\""];
				else if( r < 1.5 ) [fontstr appendString: @"\"4\""];
				else if( r < 2.3 ) [fontstr appendString: @"\"5\""];
				else if( r < 2.8 ) [fontstr appendString: @"\"6\""];
				else [fontstr appendString: @"\"7\""];
				fontFlag = YES;
			}

			[fontstr appendString:@">"];
		}

		if( ! [[options objectForKey:@"NSHTMLIgnoreFontTraits"] boolValue] ) {
			if( ( [[NSFontManager sharedFontManager] traitsOfFont:curFont] & NSBoldFontMask ) > 0 ) bFlag = YES;
			if( ( [[NSFontManager sharedFontManager] traitsOfFont:curFont] & NSItalicFontMask ) > 0 ) iFlag = YES;
			if( [dict objectForKey:NSUnderlineStyleAttributeName] ) uFlag = YES;
		}

		if( fontFlag ) [out appendString: fontstr];
		if( ! [[options objectForKey:@"NSHTMLIgnoreFontTraits"] boolValue] ) {
			if( bFlag ) [out appendString: @"<b>"];
			if( iFlag ) [out appendString: @"<i>"];
			if( uFlag ) [out appendString: @"<u>"];
		}
		if( linkFlag ) [out appendFormat: @"<a href=\"%@\">", link];

		substr = [NSMutableString stringWithString:[[self attributedSubstringFromRange:effectiveRange] string]];
		[out appendString:substr];

		if( linkFlag ) [out appendString: @"</a>"];
		if( ! [[options objectForKey:@"NSHTMLIgnoreFontTraits"] boolValue] ) {
			if( uFlag ) [out appendString: @"</u>"];
			if( iFlag ) [out appendString: @"</i>"];
			if( bFlag ) [out appendString: @"</b>"];
		}
		if( fontFlag ) [out appendString: @"</font>"];

		limitRange = NSMakeRange( NSMaxRange( effectiveRange ), NSMaxRange( limitRange ) - NSMaxRange( effectiveRange ) );
	}

	if( [[options objectForKey:@"NSHTMLFullDocument"] boolValue] )
		[out appendString: @"</body></html>"];

	ret = [[[out dataUsingEncoding:encoding allowLossyConversion:loss] mutableCopy] autorelease];
	[ret appendBytes:"\0" length:1];

	return ret;
}
@end

@implementation NSMutableAttributedString (NSMutableAttributedStringImageAdditions)
- (void) preformImageSubstitutionWithDictionary:(NSDictionary *) dict {
//	NSDictionary *attributes = nil;
	NSString *string = [self string], *str = nil;
	NSEnumerator *keyEnumerator = [dict keyEnumerator];
	NSEnumerator *objEnumerator = [dict objectEnumerator];
	NSEnumerator *srcEnumerator = nil;
	id key = nil, obj = nil;
	NSFileWrapper *imageWrapper = nil;
	NSTextAttachment *imageAttachment = nil;
	NSAttributedString *imageAttachString = nil;
	BOOL moreReplacements = YES;

	while( ( key = [keyEnumerator nextObject] ) && ( obj = [objEnumerator nextObject] ) ) {
		srcEnumerator = [obj objectEnumerator];
		while( ( str = [srcEnumerator nextObject] ) ) {
			moreReplacements = YES;
			if( [string rangeOfString:str].length && ! imageAttachString ) {
				NSString *path = [[NSBundle mainBundle] pathForResource:key ofType:nil];
				if( ! [[NSFileManager defaultManager] fileExistsAtPath:path] ) continue;
				imageWrapper = [[[NSFileWrapper alloc] initWithPath:path] autorelease];
				imageAttachment = [[[NSTextAttachment alloc] initWithFileWrapper:imageWrapper] autorelease];
				imageAttachString = [NSAttributedString attributedStringWithAttachment:imageAttachment];
				if( ! imageWrapper || ! imageAttachment || ! imageAttachString ) continue;
			}
			while( moreReplacements ) {
				NSRange range = [string rangeOfString:str];
				if( range.length ) {
					if( (signed)( range.location - 1 ) >= 0 && [string characterAtIndex:( range.location - 1 )] != ' ' )
						break;
					if( (signed)( range.location + [str length] ) < [string length] && [string characterAtIndex:( range.location + [str length] )] != ' ' )
						break;
					//attributes = [self attributesAtIndex:range.location longestEffectiveRange:NULL inRange:range];
					[self replaceCharactersInRange:range withAttributedString:imageAttachString];
					//[self addAttributes:attributes range:NSMakeRange( range.location, 1 )]; /* ~CRASH! */
				} else moreReplacements = NO;
			}
		}
		imageAttachString = nil;
	}
}

- (void) preformHTMLBackgroundColoring {
	NSRange limitRange, effectiveRange;
	HTMLDocument *html = nil;
	NSEnumerator *enumerator = nil;
	NSMutableArray *enumerators = [NSMutableArray array];
	NSMutableArray *backgrounds = [NSMutableArray array];
	NSMutableArray *listing = [NSMutableArray array];
	unsigned int location = 0, lastColor = 0;
	NSScanner *scanner = nil;
	id node = nil;

	limitRange = NSMakeRange( 0, [self length] );
	while( limitRange.length > 0 ) {
		html = [self attribute:@"HTML_Tree_Retain" atIndex:limitRange.location longestEffectiveRange:&effectiveRange inRange:limitRange];

		enumerator = [[[html htmlTree] children] objectEnumerator];
		if( enumerator ) [enumerators addObject:enumerator];
		node = [enumerator nextObject];

		location = limitRange.location;
		while( node || enumerator ) {
			if( [node isKindOfClass:[HTMLString class]] ) location += [[node string] length];
			if( [node isKindOfClass:[HTMLNode class]] && [node numberOfChildren] > 0 ) {
				if( [node isMemberOfClass:[HTMLFont class]] && [node stringValueForAttribute:@"style"] ) {
					unsigned int color = 0;
					BOOL foundColor = NO;
					scanner = [NSScanner scannerWithString:[node stringValueForAttribute:@"style"]];
					while( ! [scanner isAtEnd] ) {
						if( [scanner scanString:@"background-color:" intoString:nil] ) {
							[scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
							[scanner scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"#"] intoString:nil];
							if( [scanner scanHexInt:&color] ) {
								if( [backgrounds lastObject] ) [self addAttribute:NSBackgroundColorAttributeName value:[backgrounds lastObject] range:NSMakeRange( lastColor, location - lastColor )];
								[backgrounds addObject:[NSColor colorForHTMLAttributeValue:[NSString stringWithFormat:@"#%06x", color]]];
								foundColor = YES;
							}
							break;
						}
						[scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@";"] intoString:nil];
					}
					if( foundColor ) [listing addObject:[NSNumber numberWithBool:YES]];
					else [listing addObject:[NSNumber numberWithBool:NO]];
				} else [listing addObject:[NSNumber numberWithBool:NO]];

				lastColor = location;
				enumerator = [[node children] objectEnumerator];
				[enumerators addObject:enumerator];
				node = [enumerator nextObject];
			} else {
				node = [enumerator nextObject];
				if( ! node ) {
					[enumerators removeObjectIdenticalTo:enumerator];
					if( [[listing lastObject] boolValue] ) {
						[self addAttribute:NSBackgroundColorAttributeName value:[backgrounds lastObject] range:NSMakeRange( lastColor, location - lastColor )];
						[backgrounds removeObjectIdenticalTo:[backgrounds lastObject]];
					}
					[listing removeObjectIdenticalTo:[listing lastObject]];
					enumerator = [enumerators lastObject];
					node = [enumerator nextObject];
				}
			}
		}

		limitRange = NSMakeRange( NSMaxRange( effectiveRange ), NSMaxRange( limitRange ) - NSMaxRange( effectiveRange ) );
	}
}

- (void) preformLinkHighlighting {
	[self preformLinkHighlightingUsingColor:nil withUnderline:YES];
}

- (void) preformLinkHighlightingUsingColor:(NSColor *) linkColor withUnderline:(BOOL) underline {
	NSScanner *urlScanner = [NSScanner scannerWithString:[self string]];
	NSCharacterSet *urlStopSet = [NSCharacterSet characterSetWithCharactersInString:@" \t\n\r\0<>\"'![]{}()|*^!"];
	NSString *link = nil, *urlHandle = nil;
	unsigned lastLoc = 0;

	while( ! [urlScanner isAtEnd] ) {
		while( ! [urlScanner isAtEnd] ) {
			lastLoc = [urlScanner scanLocation];
			if( [urlScanner scanUpToString:@"://" intoString:&urlHandle] ) {
				NSRange range = [urlHandle rangeOfCharacterFromSet:urlStopSet options:NSBackwardsSearch];
				[urlScanner setScanLocation:lastLoc];
				if( ! range.length ) {
					if( lastLoc ) lastLoc += 1;
					break;
				} else if( ! [urlHandle rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]].length ) {
					lastLoc += range.location + range.length + ( lastLoc ? 1 : 0 );
					if( lastLoc < [self length] ) [urlScanner setScanLocation:lastLoc];
					else [urlScanner setScanLocation:[self length]];
					break;
				}
			}
			[urlScanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
		}
		if( [urlScanner scanUpToString:@"://" intoString:&urlHandle] && [urlScanner scanUpToCharactersFromSet:urlStopSet intoString:&link] ) {
			if( [link length] >= 7 ) {
				if( [link characterAtIndex:([link length] - 1)] == '.' || [link characterAtIndex:([link length] - 1)] == '?' )
					link = [link substringToIndex:([link length] - 1)];
				link = [urlHandle stringByAppendingString:link];
				[self addAttributes:[NSAttributedString linkAttributesForTarget:link usingColor:linkColor withUnderline:underline] range:NSMakeRange( lastLoc, [link length] )];
			}
		}
	}
	urlHandle = link = nil;
	lastLoc = 0;

	[urlScanner setScanLocation:0];
	while( ! [urlScanner isAtEnd] ) {
		while( ! [urlScanner isAtEnd] ) {
			lastLoc = [urlScanner scanLocation];
			if( [urlScanner scanUpToString:@"@" intoString:&urlHandle] ) {
				NSRange range = [urlHandle rangeOfCharacterFromSet:urlStopSet options:NSBackwardsSearch];
				[urlScanner setScanLocation:lastLoc];
				if( ! range.length ) {
					if( lastLoc ) lastLoc += 1;
					break;
				} else if( ! [urlHandle rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]].length ) {
					lastLoc += range.location + range.length + ( lastLoc ? 1 : 0 );
					if( lastLoc < [self length] ) [urlScanner setScanLocation:lastLoc];
					else [urlScanner setScanLocation:[self length]];
					break;
				}
			}
			[urlScanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:nil];
		}
		if( [urlScanner scanUpToString:@"@" intoString:&urlHandle] && [urlScanner scanUpToCharactersFromSet:urlStopSet intoString:&link] ) {
			id email = nil;
			NSRange hasPeriod = [link rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"."]];
			NSRange limitRange = NSMakeRange( lastLoc, [[urlHandle stringByAppendingString:link] length] );
			NSDictionary *attrs = [self attributesAtIndex:limitRange.location longestEffectiveRange:NULL inRange:limitRange];
			if( [urlHandle length] && [link length] && hasPeriod.location < ([link length] - 1) && hasPeriod.location != NSNotFound && ! [attrs objectForKey:NSLinkAttributeName] ) {
				email = [NSString stringWithFormat:@"mailto:%@%@", urlHandle, link];
				[self addAttributes:[NSAttributedString linkAttributesForTarget:email usingColor:linkColor withUnderline:underline] range:limitRange];
			}
		}
	}
}
@end
