// Created by Graham Booker for Fire.
// Changes by Timothy Hatcher for Colloquy.
// Copyright Graham Booker and Timothy Hatcher. All rights reserved.

#import "NSAttributedStringMoreAdditions.h"

#import <libxml/tree.h>
#import <ChatCore/NSStringAdditions.h>

static void setItalicOrObliqueFont( NSMutableDictionary *attrs ) {
	NSFontManager *fm = [NSFontManager sharedFontManager];
	NSFont *font = [attrs objectForKey:NSFontAttributeName];
	if( ! font ) font = [NSFont userFontOfSize:12];
	if( ! ( [fm traitsOfFont:font] & NSItalicFontMask ) ) {
		NSFont *newFont = [fm convertFont:font toHaveTrait:NSItalicFontMask];
		if( newFont == font ) {
			// font couldn't be made italic
			[attrs setObject:[NSNumber numberWithFloat:JVItalicObliquenessValue] forKey:NSObliquenessAttributeName];
		} else {
			// We got an italic font
			[attrs setObject:newFont forKey:NSFontAttributeName];
			[attrs removeObjectForKey:NSObliquenessAttributeName];
		}
	}
}

static void removeItalicOrObliqueFont( NSMutableDictionary *attrs ) {
	NSFontManager *fm = [NSFontManager sharedFontManager];
	NSFont *font = [attrs objectForKey:NSFontAttributeName];
	if( ! font ) font = [NSFont userFontOfSize:12];
	if( [fm traitsOfFont:font] & NSItalicFontMask ) {
		font = [fm convertFont:font toNotHaveTrait:NSItalicFontMask];
		[attrs setObject:font forKey:NSFontAttributeName];
	}
	[attrs removeObjectForKey:NSObliquenessAttributeName];
}

static NSString *parseCSSStyleAttribute( const char *style, NSMutableDictionary *currentAttributes ) {
	NSScanner *scanner = [NSScanner scannerWithString:[NSString stringWithUTF8String:style]];
	NSMutableString *unhandledStyles = [NSMutableString string];

	while( ! [scanner isAtEnd] ) {
		NSString *prop = nil;
		NSString *attr = nil;
		BOOL handled = NO;

 		[scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL];
		[scanner scanUpToString:@":" intoString:&prop];
		[scanner scanString:@":" intoString:NULL];
 		[scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL];
		[scanner scanUpToString:@";" intoString:&attr];
		[scanner scanString:@";" intoString:NULL];

		if( ! [prop length] || ! [attr length] ) continue;

		if( [prop isEqualToString:@"color"] ) {
			NSColor *color = [NSColor colorWithCSSAttributeValue:attr];
			if( color ) {
				[currentAttributes setObject:color forKey:NSForegroundColorAttributeName];
				handled = YES;
			}
		} else if( [prop isEqualToString:@"background-color"] ) {
			NSColor *color = [NSColor colorWithCSSAttributeValue:attr];
			if( color ) {
				[currentAttributes setObject:color forKey:NSBackgroundColorAttributeName];
				handled = YES;
			}
		} else if( [prop isEqualToString:@"font-weight"] ) {
			if( [attr rangeOfString:@"bold"].location != NSNotFound || [attr intValue] >= 500 ) {
				NSFont *font = [[NSFontManager sharedFontManager] convertFont:[currentAttributes objectForKey:NSFontAttributeName] toHaveTrait:NSBoldFontMask];
				if( font ) {
					[currentAttributes setObject:font forKey:NSFontAttributeName];
					handled = YES;
				}
			} else {
				NSFont *font = [[NSFontManager sharedFontManager] convertFont:[currentAttributes objectForKey:NSFontAttributeName] toNotHaveTrait:NSBoldFontMask];
				if( font ) {
					[currentAttributes setObject:font forKey:NSFontAttributeName];
					handled = YES;
				}
			}
		} else if( [prop isEqualToString:@"font-style"] ) {
			if( [attr rangeOfString:@"italic"].location != NSNotFound ) {
				setItalicOrObliqueFont( currentAttributes );
				handled = YES;
			} else {
				removeItalicOrObliqueFont( currentAttributes );
				handled = YES;
			}
		} else if( [prop isEqualToString:@"font-variant"] ) {
			if( [attr rangeOfString:@"small-caps"].location != NSNotFound ) {
				NSFont *font = [[NSFontManager sharedFontManager] convertFont:[currentAttributes objectForKey:NSFontAttributeName] toHaveTrait:NSSmallCapsFontMask];
				if( font ) {
					[currentAttributes setObject:font forKey:NSFontAttributeName];
					handled = YES;
				}
			} else {
				NSFont *font = [[NSFontManager sharedFontManager] convertFont:[currentAttributes objectForKey:NSFontAttributeName] toNotHaveTrait:NSSmallCapsFontMask];
				if( font ) {
					[currentAttributes setObject:font forKey:NSFontAttributeName];
					handled = YES;
				}
			}
		} else if( [prop isEqualToString:@"font-stretch"] ) {
			if( [attr rangeOfString:@"normal"].location != NSNotFound ) {
				NSFont *font = [[NSFontManager sharedFontManager] convertFont:[currentAttributes objectForKey:NSFontAttributeName] toNotHaveTrait:( NSCondensedFontMask | NSExpandedFontMask )];
				if( font ) {
					[currentAttributes setObject:font forKey:NSFontAttributeName];
					handled = YES;
				}
			} else if( [attr rangeOfString:@"condensed"].location != NSNotFound || [attr rangeOfString:@"narrower"].location != NSNotFound ) {
				NSFont *font = [[NSFontManager sharedFontManager] convertFont:[currentAttributes objectForKey:NSFontAttributeName] toHaveTrait:NSCondensedFontMask];
				if( font ) {
					[currentAttributes setObject:font forKey:NSFontAttributeName];
					handled = YES;
				}
			} else {
				NSFont *font = [[NSFontManager sharedFontManager] convertFont:[currentAttributes objectForKey:NSFontAttributeName] toHaveTrait:NSExpandedFontMask];
				if( font ) {
					[currentAttributes setObject:font forKey:NSFontAttributeName];
					handled = YES;
				}
			}
		} else if( [prop isEqualToString:@"text-decoration"] ) {
			if( [attr rangeOfString:@"underline"].location != NSNotFound ) {
				[currentAttributes setObject:[NSNumber numberWithInt:1] forKey:NSUnderlineStyleAttributeName];
				handled = YES;
			} else {
				[currentAttributes removeObjectForKey:NSUnderlineStyleAttributeName];
				handled = YES;
			}
		}

		if( ! handled ) {
			if( [unhandledStyles length] ) [unhandledStyles appendString:@";"];
			[unhandledStyles appendFormat:@"%@: %@", prop, attr];
		}

 		[scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL];
	}

	return ( [unhandledStyles length] ? unhandledStyles : nil );
}

static NSMutableAttributedString *parseXHTMLTreeNode( xmlNode *node, NSDictionary *currentAttributes, NSURL *base, BOOL first ) {
	if( ! node || ! node -> name || ! node -> name[0] ) return nil;

	NSMutableAttributedString *ret = [[NSMutableAttributedString new] autorelease];
	NSMutableDictionary *newAttributes = [[currentAttributes mutableCopy] autorelease];
	xmlNodePtr child = node -> children;
	BOOL skipTag = NO;

	switch( node -> name[0] ) {
	case 'i':
		if( ! strcmp( (char *) node -> name, "i" ) ) {
			setItalicOrObliqueFont( newAttributes );
			skipTag = YES;
		}
		break;
	case 'u':
		if( ! strcmp( (char *) node -> name, "u" ) ) {
			[newAttributes setObject:[NSNumber numberWithInt:1] forKey:NSUnderlineStyleAttributeName];
			skipTag = YES;
		}
		break;
	case 'a':
		if( ! strcmp( (char *) node -> name, "a" ) ) {
			xmlChar *link = xmlGetProp( node, (xmlChar *) "href" );
			if( link ) {
				[newAttributes setObject:[NSString stringWithUTF8String:(char *) link] forKey:NSLinkAttributeName];
				xmlFree( link );
				skipTag = YES;
				xmlChar *title = xmlGetProp( node, (xmlChar *) "title" );
				if( title ) {
					[newAttributes setObject:[NSString stringWithUTF8String:(char *) title] forKey:@"LinkTitle"];
					xmlFree( title );
				}
			}
		}
		break;
	case 'f':
		if( ! strcmp( (char *) node -> name, "font" ) ) {
			xmlChar *attr = xmlGetProp( node, (xmlChar *) "color" );
			if( attr ) {
				NSColor *color = [NSColor colorWithHTMLAttributeValue:[NSString stringWithUTF8String:(char *) attr]];
				if( color ) [newAttributes setObject:color forKey:NSForegroundColorAttributeName];
				xmlFree( attr );
				skipTag = YES;
			}
		}
		break;
	case 'b':
		if( ! strcmp( (char *) node -> name, "br" ) ) {
			return [[[NSAttributedString alloc] initWithString:@"\n" attributes:newAttributes] autorelease]; // known to have no content, return now
		} else if( ! strcmp( (char *) node -> name, "b" ) ) {
			NSFont *font = [[NSFontManager sharedFontManager] convertFont:[newAttributes objectForKey:NSFontAttributeName] toHaveTrait:NSBoldFontMask];
			if( font ) {
				[newAttributes setObject:font forKey:NSFontAttributeName];
				skipTag = YES;
			}
		}
		break;
	case 'p':
		if( ! strcmp( (char *) node -> name, "p" ) ) {
			NSAttributedString *newStr = [[NSAttributedString alloc] initWithString:@"\n\n" attributes:newAttributes];
			if( newStr ) {
				[ret appendAttributedString:newStr];
				[newStr release];
			}
		}
		break;
	case 's':
		if( ! strcmp( (char *) node -> name, "span" ) ) 
			skipTag = YES;
		break;
	}

	if( skipTag || first ) {
		xmlChar *classes = xmlGetProp( node, (xmlChar *) "class" );
		if( classes ) {
			NSArray *cls = [[NSString stringWithUTF8String:(char *) classes] componentsSeparatedByString:@" "];
			[newAttributes setObject:[NSSet setWithArray:cls] forKey:@"CSSClasses"];
			xmlFree( classes );
		}

		// Parse any inline CSS styles attached to this node, do this last incase the CSS overrides any of the previous attributes
		xmlChar *style = xmlGetProp( node, (xmlChar *) "style" );
		if( style ) {
			NSString *unhandledStyles = parseCSSStyleAttribute( (char *) style, newAttributes );
			if( unhandledStyles ) [newAttributes setObject:unhandledStyles forKey:@"CSSText"];
			xmlFree( style );
		}

		while( child ) {
			if( child -> type == XML_TEXT_NODE ) {
				xmlChar *content = child -> content;
				NSAttributedString *new = [[NSAttributedString alloc] initWithString:[NSString stringWithUTF8String:(char *) content] attributes:newAttributes];
				[ret appendAttributedString:new];
				[new release];
			} else [ret appendAttributedString:parseXHTMLTreeNode( child, newAttributes, base, NO )];
			child = child -> next;
		}
	} else if( ! skipTag && node -> type == XML_ELEMENT_NODE ) {
		if( ! first ) {
			NSMutableString *front = [newAttributes objectForKey:@"XHTMLStart"];
			if( ! front ) front = [NSMutableString string];

			xmlBufferPtr buf = xmlBufferCreate();
			xmlNodeDump( buf, node -> doc, node, 0, 0 );

			NSData *xmlData = [NSData dataWithBytesNoCopy:buf -> content length:buf -> use freeWhenDone:NO];
			NSString *string = [[[NSString alloc] initWithData:xmlData encoding:NSUTF8StringEncoding] autorelease];

			[front appendString:string];
			[newAttributes setObject:front forKey:@"XHTMLStart"];

			unichar attachmentChar = NSAttachmentCharacter;
			NSString *attachment = [NSString stringWithCharacters:&attachmentChar length:1];

			NSAttributedString *new = [[NSAttributedString alloc] initWithString:attachment attributes:newAttributes];
			[ret appendAttributedString:new];
			[new release];

			xmlBufferFree( buf );
		} else if( first ) {
			[newAttributes removeObjectForKey:@"XHTMLStart"];
			[newAttributes removeObjectForKey:@"XHTMLEnd"];
		}
	}

	return ret;
}

#pragma mark -

@implementation NSAttributedString (NSAttributedStringXMLAdditions)
+ (id) attributedStringWithXHTMLTree:(void *) node baseURL:(NSURL *) base defaultAttributes:(NSDictionary *) attributes {
	return [[[self alloc] initWithXHTMLTree:node baseURL:base defaultAttributes:attributes] autorelease];
}

+ (id) attributedStringWithXHTMLFragment:(NSString *) fragment baseURL:(NSURL *) base defaultAttributes:(NSDictionary *) attributes {
	return [[[self alloc] initWithXHTMLFragment:fragment baseURL:base defaultAttributes:attributes] autorelease];
}

- (id) initWithXHTMLTree:(void *) node baseURL:(NSURL *) base defaultAttributes:(NSDictionary *) attributes {
	NSMutableDictionary *attrs = [NSMutableDictionary dictionaryWithDictionary:attributes];
	if( ! [attrs objectForKey:NSFontAttributeName] )
		[attrs setObject:[NSFont userFontOfSize:12.] forKey:NSFontAttributeName];
	id ret = parseXHTMLTreeNode( (xmlNode *) node, attrs, base, YES );
	return ( self = [self initWithAttributedString:ret] );
}

- (id) initWithXHTMLFragment:(NSString *) fragment baseURL:(NSURL *) base defaultAttributes:(NSDictionary *) attributes {
	const char *string = [[NSString stringWithFormat:@"<root>%@</root>", [fragment stringByStrippingIllegalXMLCharacters]] UTF8String];

	if( string ) {
		xmlDocPtr tempDoc = xmlParseMemory( string, strlen( string ) );
		self = [self initWithXHTMLTree:xmlDocGetRootElement( tempDoc ) baseURL:base defaultAttributes:attributes];
		xmlFreeDoc( tempDoc );
		return self;
	}

	[self autorelease];
	return nil;
}
@end

#pragma mark -

@implementation NSMutableAttributedString (NSMutableAttributedStringHTMLAdditions)
- (void) makeLinkAttributesAutomatically {
	// catch well-formed urls like "http://www.apple.com", "www.apple.com" or "irc://irc.javelin.cc"
	AGRegex *regex = [AGRegex regexWithPattern:@"(?:[a-zA-Z][a-zA-Z0-9+.-]{2,}://|www\\.)[\\p{L}\\p{N}$\\-_+*'\"=\\|/\\\\(){}[\\]%@&#~,:;.!?]{4,}[\\p{L}\\p{N}$\\-_+*=\\|/\\\\({%@&#~]" options:AGRegexCaseInsensitive];
	NSArray *matches = [regex findAllInString:[self string]];
	NSEnumerator *enumerator = [matches objectEnumerator];
	AGRegexMatch *match = nil;

	while( ( match = [enumerator nextObject] ) ) {
		NSRange foundRange = [match range];
		NSString *currentLink = [self attribute:NSLinkAttributeName atIndex:foundRange.location effectiveRange:NULL];
		if( ! currentLink ) [self addAttribute:NSLinkAttributeName value:( [[match group] hasPrefix:@"www."] ? [@"http://" stringByAppendingString:[match group]] : [match group] ) range:foundRange];
	}

	// catch well-formed email addresses like "timothy@hatcher.name" or "timothy@javelin.cc"
	regex = [AGRegex regexWithPattern:@"[\\p{L}\\p{N}.+-]+@(?:[\\p{L}-]+\\.)+[\\w]{2,}" options:AGRegexCaseInsensitive];
	matches = [regex findAllInString:[self string]];
	enumerator = [matches objectEnumerator];
	match = nil;

	while( ( match = [enumerator nextObject] ) ) {
		NSRange foundRange = [match range];
		NSString *currentLink = [self attribute:NSLinkAttributeName atIndex:foundRange.location effectiveRange:NULL];
		if( ! currentLink ) {
			NSString *link = [NSString stringWithFormat:@"mailto:%@", [match group]];
			[self addAttribute:NSLinkAttributeName value:link range:foundRange];
		}
	}
}
@end
