// Created by Graham Booker for Fire.
// Changes by Timothy Hatcher for Colloquy.
// Copyright Graham Booker and Timothy Hatcher. All rights reserved.

#include <libxml/tree.h>

#import "NSAttributedStringMoreAdditions.h"
#import "NSRegularExpressionAdditions.h"

#import <ChatCore/NSStringAdditions.h>

static void setItalicOrObliqueFont( NSMutableDictionary *attrs ) {
	NSFontManager *fm = [NSFontManager sharedFontManager];
	NSFont *font = attrs[NSFontAttributeName];
	if( ! font ) font = [NSFont userFontOfSize:12];
	if( ! ( [fm traitsOfFont:font] & NSItalicFontMask ) ) {
		NSFont *newFont = [fm convertFont:font toHaveTrait:NSItalicFontMask];
		if( newFont == font ) {
			// font couldn't be made italic
			attrs[NSObliquenessAttributeName] = @(JVItalicObliquenessValue);
		} else {
			// We got an italic font
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

static NSString *parseCSSStyleAttribute( const char *style, NSMutableDictionary *currentAttributes ) {
	NSScanner *scanner = [NSScanner scannerWithString:@(style)];
	NSMutableString *unhandledStyles = [[NSMutableString alloc] init];

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
				currentAttributes[NSForegroundColorAttributeName] = color;
				handled = YES;
			}
		} else if( [prop isEqualToString:@"background-color"] ) {
			NSColor *color = [NSColor colorWithCSSAttributeValue:attr];
			if( color ) {
				currentAttributes[NSBackgroundColorAttributeName] = color;
				handled = YES;
			}
		} else if( [prop isEqualToString:@"font-weight"] ) {
			if( [attr rangeOfString:@"bold"].location != NSNotFound || [attr intValue] >= 500 ) {
				NSFont *font = [[NSFontManager sharedFontManager] convertFont:currentAttributes[NSFontAttributeName] toHaveTrait:NSBoldFontMask];
				if( font ) {
					currentAttributes[NSFontAttributeName] = font;
					handled = YES;
				}
			} else {
				NSFont *font = [[NSFontManager sharedFontManager] convertFont:currentAttributes[NSFontAttributeName] toNotHaveTrait:NSBoldFontMask];
				if( font ) {
					currentAttributes[NSFontAttributeName] = font;
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
				NSFont *font = [[NSFontManager sharedFontManager] convertFont:currentAttributes[NSFontAttributeName] toHaveTrait:NSSmallCapsFontMask];
				if( font ) {
					currentAttributes[NSFontAttributeName] = font;
					handled = YES;
				}
			} else {
				NSFont *font = [[NSFontManager sharedFontManager] convertFont:currentAttributes[NSFontAttributeName] toNotHaveTrait:NSSmallCapsFontMask];
				if( font ) {
					currentAttributes[NSFontAttributeName] = font;
					handled = YES;
				}
			}
		} else if( [prop isEqualToString:@"font-stretch"] ) {
			if( [attr rangeOfString:@"normal"].location != NSNotFound ) {
				NSFont *font = [[NSFontManager sharedFontManager] convertFont:currentAttributes[NSFontAttributeName] toNotHaveTrait:( NSCondensedFontMask | NSExpandedFontMask )];
				if( font ) {
					currentAttributes[NSFontAttributeName] = font;
					handled = YES;
				}
			} else if( [attr rangeOfString:@"condensed"].location != NSNotFound || [attr rangeOfString:@"narrower"].location != NSNotFound ) {
				NSFont *font = [[NSFontManager sharedFontManager] convertFont:currentAttributes[NSFontAttributeName] toHaveTrait:NSCondensedFontMask];
				if( font ) {
					currentAttributes[NSFontAttributeName] = font;
					handled = YES;
				}
			} else {
				NSFont *font = [[NSFontManager sharedFontManager] convertFont:currentAttributes[NSFontAttributeName] toHaveTrait:NSExpandedFontMask];
				if( font ) {
					currentAttributes[NSFontAttributeName] = font;
					handled = YES;
				}
			}
		} else if( [prop isEqualToString:@"text-decoration"] ) {
			if( [attr rangeOfString:@"underline"].location != NSNotFound ) {
				currentAttributes[NSUnderlineStyleAttributeName] = @1UL;
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

	NSMutableAttributedString *ret = [NSMutableAttributedString new];
	NSMutableDictionary *newAttributes = [currentAttributes mutableCopy];
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
			newAttributes[NSUnderlineStyleAttributeName] = @1UL;
			skipTag = YES;
		}
		break;
	case 'a':
		if( ! strcmp( (char *) node -> name, "a" ) ) {
			xmlChar *link = xmlGetProp( node, (xmlChar *) "href" );
			if( link ) {
				newAttributes[NSLinkAttributeName] = @((char *) link);
				xmlFree( link );
				skipTag = YES;
				xmlChar *title = xmlGetProp( node, (xmlChar *) "title" );
				if( title ) {
					newAttributes[@"LinkTitle"] = @((char *) title);
					xmlFree( title );
				}
			}
		}
		break;
	case 'f':
		if( ! strcmp( (char *) node -> name, "font" ) ) {
			xmlChar *attr = xmlGetProp( node, (xmlChar *) "color" );
			if( attr ) {
				NSColor *color = [NSColor colorWithHTMLAttributeValue:@((char *) attr)];
				if( color ) newAttributes[NSForegroundColorAttributeName] = color;
				xmlFree( attr );
				skipTag = YES;
			}
		}
		break;
	case 'b':
		if( ! strcmp( (char *) node -> name, "br" ) ) {
			return [[NSMutableAttributedString alloc] initWithString:@"\n" attributes:newAttributes]; // known to have no content, return now
		} else if( ! strcmp( (char *) node -> name, "b" ) ) {
			NSFont *font = [[NSFontManager sharedFontManager] convertFont:newAttributes[NSFontAttributeName] toHaveTrait:NSBoldFontMask];
			if( font ) {
				newAttributes[NSFontAttributeName] = font;
				skipTag = YES;
			}
		}
		break;
	case 'p':
		if( ! strcmp( (char *) node -> name, "p" ) ) {
			NSAttributedString *newStr = [[NSAttributedString alloc] initWithString:@"\n\n" attributes:newAttributes];
			if( newStr ) {
				[ret appendAttributedString:newStr];
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
			NSArray *cls = [@((char *) classes) componentsSeparatedByString:@" "];
			newAttributes[@"CSSClasses"] = [NSSet setWithArray:cls];
			xmlFree( classes );
		}

		// Parse any inline CSS styles attached to this node, do this last incase the CSS overrides any of the previous attributes
		xmlChar *style = xmlGetProp( node, (xmlChar *) "style" );
		if( style ) {
			NSString *unhandledStyles = parseCSSStyleAttribute( (char *) style, newAttributes );
			if( unhandledStyles ) newAttributes[@"CSSText"] = unhandledStyles;
			xmlFree( style );
		}

		while( child ) {
			if( child -> type == XML_TEXT_NODE ) {
				xmlChar *content = child -> content;
				NSAttributedString *new = [[NSAttributedString alloc] initWithString:@((char *) content) attributes:newAttributes];
				[ret appendAttributedString:new];
			} else [ret appendAttributedString:parseXHTMLTreeNode( child, newAttributes, base, NO )];
			child = child -> next;
		}
	} else if( ! skipTag && node -> type == XML_ELEMENT_NODE ) {
		if( ! first ) {
			NSMutableString *front = newAttributes[@"XHTMLStart"];
			if( ! front ) front = [[NSMutableString alloc] init];

			xmlBufferPtr buf = xmlBufferCreate();
			xmlNodeDump( buf, node -> doc, node, 0, 0 );

			NSData *xmlData = [NSData dataWithBytesNoCopy:buf -> content length:buf -> use freeWhenDone:NO];
			NSString *string = [[NSString alloc] initWithData:xmlData encoding:NSUTF8StringEncoding];

			[front appendString:string];
			newAttributes[@"XHTMLStart"] = front;

			unichar attachmentChar = NSAttachmentCharacter;
			NSString *attachment = [[NSString alloc] initWithCharacters:&attachmentChar length:1];

			NSAttributedString *new = [[NSAttributedString alloc] initWithString:attachment attributes:newAttributes];
			[ret appendAttributedString:new];

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
+ (id) attributedStringWithXHTMLTree:(struct _xmlNode *) node baseURL:(NSURL *) base defaultAttributes:(NSDictionary *) attributes {
	return [[self alloc] initWithXHTMLTree:node baseURL:base defaultAttributes:attributes];
}

+ (id) attributedStringWithXHTMLFragment:(NSString *) fragment baseURL:(NSURL *) base defaultAttributes:(NSDictionary *) attributes {
	return [[self alloc] initWithXHTMLFragment:fragment baseURL:base defaultAttributes:attributes];
}

- (instancetype) initWithXHTMLTree:(struct _xmlNode *) node baseURL:(NSURL *) base defaultAttributes:(NSDictionary *) attributes {
	NSMutableDictionary *attrs = [attributes mutableCopy];
	if( ! attrs[NSFontAttributeName] )
		attrs[NSFontAttributeName] = [NSFont userFontOfSize:12.];
	id ret = parseXHTMLTreeNode( node, attrs, base, YES );
	return [self initWithAttributedString:ret];
}

- (instancetype) initWithXHTMLFragment:(NSString *) fragment baseURL:(NSURL *) base defaultAttributes:(NSDictionary *) attributes {
	const char *string = [[[NSString alloc] initWithFormat:@"<root>%@</root>", [fragment stringByStrippingIllegalXMLCharacters]] UTF8String];

	if( string ) {
		xmlDocPtr tempDoc = xmlParseMemory( string, (int)strlen( string ) );
		self = [self initWithXHTMLTree:xmlDocGetRootElement( tempDoc ) baseURL:base defaultAttributes:attributes];
		xmlFreeDoc( tempDoc );
		return self;
	}

	return nil;
}
@end
	
#pragma mark -

@implementation NSMutableAttributedString (NSMutableAttributedStringHTMLAdditions)
- (void) makeLinkAttributesAutomatically {
	// catch well-formed urls like "http://www.apple.com", "www.apple.com" or "irc://irc.javelin.cc"
	static NSDataDetector *linkDataDetector = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		linkDataDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];
	});

	for ( NSTextCheckingResult *match in [linkDataDetector matchesInString:[self string] options:0 range:NSMakeRange( 0, [self string].length )]) {
		NSRange foundRange = [match range];
		NSString *currentLink = [self attribute:NSLinkAttributeName atIndex:foundRange.location effectiveRange:NULL];
		NSString *contents = [[self string] substringWithRange:foundRange];
		if( ! currentLink ) [self addAttribute:NSLinkAttributeName value:( [contents hasCaseInsensitivePrefix:@"www."] ? [@"http://" stringByAppendingString:contents] : contents ) range:foundRange];
	}

	// catch well-formed email addresses like "timothy@hatcher.name" or "timothy@javelin.cc"
	NSRegularExpression *emailRegex = [NSRegularExpression cachedRegularExpressionWithPattern:@"[\\p{L}\\p{N}.+\\-_]+@(?:[\\p{L}\\-_]+\\.)+[\\w]{2,}" options:NSRegularExpressionCaseInsensitive error:nil];

	for( NSTextCheckingResult *match in [emailRegex matchesInString:[self string] options:0 range:NSMakeRange( 0, [self string].length )] ) {
		NSRange foundRange = [match range];
		NSString *currentLink = [self attribute:NSLinkAttributeName atIndex:foundRange.location effectiveRange:NULL];
		if( ! currentLink ) {
			NSString *contents = [[self string] substringWithRange:foundRange];
			NSString *link = [[NSString alloc] initWithFormat:@"mailto:%@", contents];
			[self addAttribute:NSLinkAttributeName value:link range:foundRange];
		}
	}
}
@end
