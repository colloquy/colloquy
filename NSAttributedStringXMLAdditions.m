// Created by Graham Booker for Fire.
// Changes by Timothy Hatcher for Colloquy.
// Copyright Graham Booker and Timothy Hatcher. All rights reserved.

#import <Cocoa/Cocoa.h>
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
				NSFont *font = [[NSFontManager sharedFontManager] convertFont:[currentAttributes objectForKey:NSFontAttributeName] toHaveTrait:NSItalicFontMask];
				if( font ) {
					[currentAttributes setObject:font forKey:NSFontAttributeName];
					handled = YES;
				}
			} else {
				NSFont *font = [[NSFontManager sharedFontManager] convertFont:[currentAttributes objectForKey:NSFontAttributeName] toNotHaveTrait:NSItalicFontMask];
				if( font ) {
					[currentAttributes setObject:font forKey:NSFontAttributeName];
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
		if( ! strcmp( node -> name, "img" ) ) {
			xmlBufferPtr buf = xmlBufferCreate();
			xmlNodeDump( buf, node -> doc, node, 0, 0 );

			NSData *imgCode = [NSData dataWithBytesNoCopy:buf -> content length:buf -> use freeWhenDone:NO];
			NSAttributedString *newStr = nil;

			if( NSAppKitVersionNumber >= 700. ) newStr = [[NSMutableAttributedString alloc] initWithHTML:imgCode options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:1], @"UseWebKit", @"utf-8", @"TextEncodingName", base, @"BaseURL", nil] documentAttributes:NULL];
			else newStr = [[NSAttributedString alloc] initWithHTML:imgCode baseURL:base documentAttributes:nil];

			xmlBufferFree( buf );

			if( newStr ) {
				[ret appendAttributedString:newStr];
				[newStr release];
			}

			skipTag = YES;
		} else if( ! strcmp( node -> name, "i" ) ) {
			NSFont *font = [[NSFontManager sharedFontManager] convertFont:[newAttributes objectForKey:NSFontAttributeName] toHaveTrait:NSItalicFontMask];
			if( font ) {
				[newAttributes setObject:font forKey:NSFontAttributeName];
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

			if( ! skipTag ) {
				[front appendString:@">"];
				[newAttributes setObject:front forKey:@"XHTMLStart"];

				NSMutableString *ending = [newAttributes objectForKey:@"XHTMLEnd"];
				if( ! ending ) ending = [NSMutableString string];
				[ending setString:[NSString stringWithFormat:@"</%s>%@", node -> name, ending]];
				[newAttributes setObject:ending forKey:@"XHTMLEnd"];
			}
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
+ (id) attributedStringWithXHTMLTree:(void *) node baseURL:(NSURL *) base defaultFont:(NSFont *) font {
	return [[[self alloc] initWithXHTMLTree:node baseURL:base defaultFont:font] autorelease];
}

- (id) initWithXHTMLTree:(void *) node baseURL:(NSURL *) base defaultFont:(NSFont *) font {
	if( ! font ) font = [NSFont userFontOfSize:12.];
	id ret = parseXHTMLTreeNode( (xmlNode *) node, [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, nil], base, YES );
	return ( self = [self initWithAttributedString:ret] );
}
@end

#pragma mark -

@implementation NSMutableAttributedString (NSMutableAttributedStringHTMLAdditions)
- (void) makeLinkAttributesAutomatically {
	/*	unsigned i = 0, c = 0;
	NSMutableArray *parts = nil;
	NSMutableString *part = nil;
	NSScanner *urlScanner = nil;
	NSCharacterSet *legalSchemeSet = nil;
	NSCharacterSet *legalAddressSet = nil;
	NSCharacterSet *legalDomainSet = nil;
	NSCharacterSet *ircChannels = [NSCharacterSet characterSetWithCharactersInString:@"#&"];
	NSCharacterSet *trailingPuncuation = [NSCharacterSet characterSetWithCharactersInString:@".!?,])}\\'\"&"];
	NSCharacterSet *seperaters = [NSCharacterSet characterSetWithCharactersInString:@"<> \t\n\r&"];
	NSString *link = nil, *urlHandle = nil;
	NSMutableString *mutableLink = nil;
	BOOL inTag = NO;
	NSRange range, srange;
	
	for( i = 0, c = [parts count]; i < c; i++ ) {
		part = [[[parts objectAtIndex:i] mutableCopy] autorelease];
		
		if( ! [part length] || ( [part length] >= 1 && [part characterAtIndex:0] == '<' ) )
			continue;
		
		// catch well-formed urls like "http://www.apple.com" or "irc://irc.javelin.cc"
		legalSchemeSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-"];
		legalAddressSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890:;#.,\\/?!&%$-+=_~@*'\"()[]"];
		legalDomainSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-_.!~*'()[]%;:&=+$,"];
		urlScanner = [NSScanner scannerWithString:part];
		srange = [part rangeOfString:@"://"];
		range = [part rangeOfCharacterFromSet:[legalSchemeSet invertedSet] options:( NSLiteralSearch | NSBackwardsSearch ) range:NSMakeRange( 0, ( srange.location != NSNotFound ? srange.location : 0 ) )];
		if( range.location != NSNotFound ) [urlScanner setScanLocation:range.location];
		[urlScanner scanUpToCharactersFromSet:legalSchemeSet intoString:NULL];
		if( [urlScanner scanUpToString:@"://" intoString:&urlHandle] && [urlScanner scanCharactersFromSet:legalAddressSet intoString:&link] ) {
			link = [link stringByTrimmingCharactersInSet:trailingPuncuation];
			if( [link length] >= 4 )
				link = [urlHandle stringByAppendingString:link];
			if( [link length] >= 7 ) {
				mutableLink = [[link mutableCopy] autorelease];
				[mutableLink replaceOccurrencesOfString:@"/" withString:@"/&#8203;" options:NSLiteralSearch range:NSMakeRange( 0, [mutableLink length] )];
				[mutableLink replaceOccurrencesOfString:@"+" withString:@"+&#8203;" options:NSLiteralSearch range:NSMakeRange( 0, [mutableLink length] )];
				[mutableLink replaceOccurrencesOfString:@"%" withString:@"&#8203;%" options:NSLiteralSearch range:NSMakeRange( 0, [mutableLink length] )];
				[mutableLink replaceOccurrencesOfString:@"&" withString:@"&#8203;&" options:NSLiteralSearch range:NSMakeRange( 0, [mutableLink length] )];
				[part replaceOccurrencesOfString:link withString:[NSString stringWithFormat:@"<a href=\"%@\">%@</a>", link, mutableLink] options:NSLiteralSearch range:NSMakeRange( 0, [part length] )];
				goto finish;
			}
		}
		
		// catch www urls like "www.apple.com"
		urlScanner = [NSScanner scannerWithString:part];
		[urlScanner scanUpToString:@"www." intoString:NULL];
		// Skip them if they come immediately after an alphanumeric character
		if( [urlScanner scanLocation] == 0 || ! [legalSchemeSet characterIsMember:[part characterAtIndex:[urlScanner scanLocation] - 1]] ) {
			NSString *domain = @"", *path = @"";
			if( [urlScanner scanCharactersFromSet:legalDomainSet intoString:&domain] ) {
				NSRange dotRange = [domain rangeOfString:@".."];
				if( dotRange.location != NSNotFound )
					domain = [domain substringWithRange:NSMakeRange( 0, dotRange.location )];
				if( [[domain componentsSeparatedByString:@"."] count] >= 3 ) {
					if( [urlScanner scanString:@"/" intoString:nil] ) {
						[urlScanner scanCharactersFromSet:legalAddressSet intoString:&path];
						link = [NSString stringWithFormat:@"%@/%@", domain, path];
					} else link = domain;
					link = [link stringByTrimmingCharactersInSet:trailingPuncuation];
					mutableLink = [[link mutableCopy] autorelease];
					[mutableLink replaceOccurrencesOfString:@"/" withString:@"/&#8203;" options:NSLiteralSearch range:NSMakeRange( 0, [mutableLink length] )];
					[mutableLink replaceOccurrencesOfString:@"+" withString:@"+&#8203;" options:NSLiteralSearch range:NSMakeRange( 0, [mutableLink length] )];
					[mutableLink replaceOccurrencesOfString:@"%" withString:@"&#8203;%" options:NSLiteralSearch range:NSMakeRange( 0, [mutableLink length] )];
					[mutableLink replaceOccurrencesOfString:@"&" withString:@"&#8203;&" options:NSLiteralSearch range:NSMakeRange( 0, [mutableLink length] )];
					[part replaceOccurrencesOfString:link withString:[NSString stringWithFormat:@"<a href=\"http://%@\">%@</a>", link, mutableLink] options:NSLiteralSearch range:NSMakeRange( 0, [part length] )];
					goto finish;
				}
			}
		}
		
		// catch well-formed email addresses like "timothy@hatcher.name" or "timothy@javelin.cc"
		legalSchemeSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890._-+"];
		legalAddressSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890@.-_"];
		urlScanner = [NSScanner scannerWithString:part];
		srange = [part rangeOfString:@"@"];
		range = [part rangeOfCharacterFromSet:[legalSchemeSet invertedSet] options:( NSLiteralSearch | NSBackwardsSearch ) range:NSMakeRange( 0, ( srange.location != NSNotFound ? srange.location : 0 ) )];
		if( range.location != NSNotFound ) [urlScanner setScanLocation:range.location];
		[urlScanner scanUpToCharactersFromSet:legalSchemeSet intoString:NULL];
		if( [urlScanner scanUpToString:@"@" intoString:&urlHandle] && [urlScanner scanCharactersFromSet:legalAddressSet intoString:&link] ) {
			link = [link stringByTrimmingCharactersInSet:trailingPuncuation];
			NSRange hasPeriod = [link rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"."]];
			if( [urlHandle length] && [link length] && hasPeriod.location < ([link length] - 1) && hasPeriod.location != NSNotFound ) {
				link = [urlHandle stringByAppendingString:link];
				[part replaceOccurrencesOfString:link withString:[NSString stringWithFormat:@"<a href=\"mailto:%@\">%@</a>", link, link] options:NSLiteralSearch range:NSMakeRange( 0, [part length] )];
				goto finish;
			}
		}
		
		// catch well-formed IRC channel names like "#php" or "&admins"
		legalAddressSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890:;.,?!%^$@#&*~`\\|+/-_"];
		urlScanner = [NSScanner scannerWithString:part];
		if( ( ( [urlScanner scanUpToCharactersFromSet:ircChannels intoString:NULL] && [urlScanner scanLocation] < [part length] && ! [[NSCharacterSet alphanumericCharacterSet] characterIsMember:[part characterAtIndex:( [urlScanner scanLocation] - 1 )]] ) || [part rangeOfCharacterFromSet:ircChannels].location == 0 ) && [urlScanner scanCharactersFromSet:legalAddressSet intoString:&urlHandle] ) {
			if( [urlHandle length] >= 2 && [urlHandle rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet] options:NSLiteralSearch range:NSMakeRange( 1, [urlHandle length] - 1 )].location != NSNotFound && ! ( [urlHandle length] == 7 && [NSColor colorWithHTMLAttributeValue:urlHandle] ) && ! ( [urlHandle characterAtIndex:0] == '&' && [urlHandle characterAtIndex:([urlHandle length] - 1)] == ';' ) ) {
				urlHandle = [urlHandle stringByTrimmingCharactersInSet:trailingPuncuation];
				link = [NSString stringWithFormat:@"irc://%@/%@", [[self connection] server], urlHandle];
				mutableLink = [NSMutableString stringWithFormat:@"<a href=\"%@\">%@</a>", link, urlHandle];
				[mutableLink replaceOccurrencesOfString:@"&" withString:@"~amp;amp;" options:NSLiteralSearch range:NSMakeRange( 0, [part length] )];
				[part replaceOccurrencesOfString:urlHandle withString:mutableLink options:NSLiteralSearch range:NSMakeRange( 0, [part length] )];
				goto finish;
			}
		}
		
finish:
			[parts replaceObjectAtIndex:i withObject:part];
	}
	
	[string setString:[parts componentsJoinedByString:@""]]; */
}
@end