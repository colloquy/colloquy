// Created by Graham Booker for Fire.
// Changes by Timothy Hatcher for Colloquy.
// Copyright Graham Booker and Timothy Hatcher. All rights reserved.

#import <ChatCore/NSAttributedStringAdditions.h>
#import <ChatCore/NSStringAdditions.h>
#import <ChatCore/NSColorAdditions.h>
#import <libxml/xinclude.h>
#import "NSAttributedStringMoreAdditions.h"

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
				NSFont *oldFont = [currentAttributes objectForKey:NSFontAttributeName];
				NSFont *font = [[NSFontManager sharedFontManager] convertFont:oldFont toHaveTrait:NSItalicFontMask];
				if( ! [font isEqual:oldFont] ) {
					[currentAttributes setObject:font forKey:NSFontAttributeName];
					handled = YES;
				} else {
					[currentAttributes setObject:[NSNumber numberWithFloat:JVItalicObliquenessValue] forKey:NSObliquenessAttributeName];
					handled = YES;
				}
			} else {
				NSFont *oldFont = [currentAttributes objectForKey:NSFontAttributeName];
				NSFont *font = [[NSFontManager sharedFontManager] convertFont:oldFont toNotHaveTrait:NSItalicFontMask];
				if( ! [font isEqual:oldFont] ) {
					[currentAttributes setObject:font forKey:NSFontAttributeName];
					handled = YES;
				} else {
					[currentAttributes removeObjectForKey:NSObliquenessAttributeName];
					handled = YES;
				}
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
			if( [unhandledStyles length] ) [unhandledStyles appendString:@"; "];
			[unhandledStyles appendFormat:@"%@: %@", prop, attr];
		}

 		[scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] intoString:NULL];
	}

	return ( [unhandledStyles length] ? unhandledStyles : nil );
}

static NSMutableAttributedString *parseXHTMLTreeNode( xmlNode *node, NSDictionary *currentAttributes, NSURL *base, BOOL first ) {
	if( ! node ) return nil;

	NSMutableAttributedString *ret = [[NSMutableAttributedString new] autorelease];
	NSMutableDictionary *newAttributes = [[currentAttributes mutableCopy] autorelease];
	xmlNodePtr child = node -> children;
	xmlChar *content = node -> content;
	BOOL skipTag = NO;

	switch( node -> name[0] ) {
	case 'i':
		/* if( ! strcmp( node -> name, "img" ) ) {
			xmlBufferPtr buf = xmlBufferCreate();
			xmlNodeDump( buf, node -> doc, node, 0, 0 );

			NSData *imgCode = [NSData dataWithBytesNoCopy:buf -> content length:buf -> use freeWhenDone:NO];
			NSAttributedString *newStr = nil;

			if( NSAppKitVersionNumber >= 700. ) newStr = [[NSMutableAttributedString alloc] initWithHTML:imgCode options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:1], @"UseWebKit", @"utf-8", @"TextEncodingName", ( base ? base : [[NSURL new] autorelease] ), @"BaseURL", nil] documentAttributes:NULL];
			else newStr = [[NSAttributedString alloc] initWithHTML:imgCode baseURL:base documentAttributes:nil];

			xmlBufferFree( buf );

			if( newStr ) {
				[ret appendAttributedString:newStr];
				[newStr release];
			}

			skipTag = YES;
		} else */ if( ! strcmp( node -> name, "i" ) ) {
			NSFont *oldFont = [newAttributes objectForKey:NSFontAttributeName];
			NSFont *font = [[NSFontManager sharedFontManager] convertFont:oldFont toHaveTrait:NSItalicFontMask];
			if( ! [font isEqual:oldFont] ) {
				[newAttributes setObject:font forKey:NSFontAttributeName];
				skipTag = YES;
			} else {
				[newAttributes setObject:[NSNumber numberWithFloat:JVItalicObliquenessValue] forKey:NSObliquenessAttributeName];
				skipTag = YES;
			}
		}
		break;
	case 'u':
		if( ! strcmp( node -> name, "u" ) ) {
			[newAttributes setObject:[NSNumber numberWithInt:1] forKey:NSUnderlineStyleAttributeName];
			skipTag = YES;
		}
		break;
	case 'a':
		if( ! strcmp( node -> name, "a" ) ) {
			xmlChar *link = xmlGetProp( node, "href" );
			if( link ) {
				[newAttributes setObject:[NSString stringWithUTF8String:link] forKey:NSLinkAttributeName];
				xmlFree( link );
				skipTag = YES;
			}
		}
		break;
	case 'f':
		if( ! strcmp( node -> name, "font" ) ) {
			xmlChar *attr = xmlGetProp( node, "color" );
			if( attr ) {
				NSColor *color = [NSColor colorWithHTMLAttributeValue:[NSString stringWithUTF8String:attr]];
				if( color ) [newAttributes setObject:color forKey:NSForegroundColorAttributeName];
				xmlFree( attr );
				skipTag = YES;
			}
		}
		break;
	case 'b':
		if( ! strcmp( node -> name, "br" ) ) {
			return [[[NSAttributedString alloc] initWithString:@"\n" attributes:newAttributes] autorelease]; // known to have no content, return now
		} else if( ! strcmp( node -> name, "b" ) ) {
			NSFont *font = [[NSFontManager sharedFontManager] convertFont:[newAttributes objectForKey:NSFontAttributeName] toHaveTrait:NSBoldFontMask];
			if( font ) {
				[newAttributes setObject:font forKey:NSFontAttributeName];
				skipTag = YES;
			}
		}
		break;
	case 'p':
		if( ! strcmp( node -> name, "p" ) ) {
			NSAttributedString *newStr = [[NSAttributedString alloc] initWithString:@"\n\n" attributes:newAttributes];
			if( newStr ) {
				[ret appendAttributedString:newStr];
				[newStr release];
			}
		}
	}

	// Parse and inline CSS styles attached to this node, do this last incase the CSS overrides any of the previous attributes
	xmlChar *style = xmlGetProp( node, "style" );
	NSString *unhandledStyles = nil;
	if( style ) {
		unhandledStyles = parseCSSStyleAttribute( style, newAttributes );
		xmlFree( style );
	}

	if( node -> type == XML_ELEMENT_NODE ) {
		if( ! first && ! skipTag ) {
			int count = 0;

			NSMutableString *front = [newAttributes objectForKey:@"XHTMLStart"];
			if( ! front ) front = [NSMutableString string];
			[front appendFormat:@"<%s", node -> name];

			xmlAttrPtr prop = NULL;
			for( prop = node -> properties; prop; prop = prop -> next ) {
				if( ! strcmp( prop -> name, "style" ) ) {
					if( [unhandledStyles length] ) {
						[front appendFormat:@" %s=\"%@\"", prop -> name, unhandledStyles];
						count++;
					}
					continue;
				}

				xmlChar *value = xmlGetProp( node, prop -> name );
				if( value ) {
					[front appendFormat:@" %s=\"%s\"", prop -> name, value];
					count++;
					xmlFree( value );
				}
			}

			if( ! strcmp( node -> name, "span" ) && ! count )
				skipTag = YES;

			[front appendString:@">"];
			[newAttributes setObject:front forKey:@"XHTMLStart"];

			NSMutableString *ending = [newAttributes objectForKey:@"XHTMLEnd"];
			if( ! ending ) ending = [NSMutableString string];
			[ending setString:[NSString stringWithFormat:@"</%s>%@", node -> name, ending]];
			[newAttributes setObject:ending forKey:@"XHTMLEnd"];
		} else if( first ) {
			[newAttributes removeObjectForKey:@"XHTMLStart"];
			[newAttributes removeObjectForKey:@"XHTMLEnd"];
		}
	}

	if( content ) {
		NSAttributedString *new = [[NSAttributedString alloc] initWithString:[NSString stringWithUTF8String:content] attributes:newAttributes];
		[ret appendAttributedString:new];
		[new release];
	}

	while( child ) {
		[ret appendAttributedString:parseXHTMLTreeNode( child, newAttributes, base, NO )];
		child = child -> next;
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
	const char *string = [[NSString stringWithFormat:@"<root>%@</root>", fragment] UTF8String];

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
	AGRegex *regex = [AGRegex regexWithPattern:@"(?:[\\w-]+://|www\\.)(?:[\\w-:]+@)?(?:[\\w-]+\\.)+[\\w{2,4}]+(?:\\:\\d+)?(?:[/?][\\w$\\-_.+!*',=:/\\\\()%@&;#?~]*)*" options:AGRegexCaseInsensitive];
	NSArray *matches = [regex findAllInString:[self string]];
	NSEnumerator *enumerator = [matches objectEnumerator];
	AGRegexMatch *match = nil;

	while( ( match = [enumerator nextObject] ) ) {
		NSRange foundRange = [match range];
		NSString *currentLink = [self attribute:NSLinkAttributeName atIndex:foundRange.location effectiveRange:NULL];
		if( ! currentLink ) [self addAttribute:NSLinkAttributeName value:( [[match group] hasPrefix:@"www."] ? [@"http://" stringByAppendingString:[match group]] : [match group] ) range:foundRange];
	}

	// catch well-formed email addresses like "timothy@hatcher.name" or "timothy@javelin.cc"
	regex = [AGRegex regexWithPattern:@"[\\w.-]+@(?:[\\w-]+\\.)+[\\w]{2,}" options:AGRegexCaseInsensitive];
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