#import <Cocoa/Cocoa.h>
#import "NSAttributedStringAdditions.h"
#import "NSColorAdditions.h"
#import "NSStringAdditions.h"

@implementation NSAttributedString (NSAttributedStringHTMLAdditions)
- (NSData *) HTMLWithOptions:(NSDictionary *) options usingEncoding:(NSStringEncoding) encoding allowLossyConversion:(BOOL) loss {
	NSRange limitRange, effectiveRange;
	NSMutableString *out = nil;
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

		if( link ) linkFlag = YES;

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

	return [out dataUsingEncoding:encoding allowLossyConversion:loss];
}
@end