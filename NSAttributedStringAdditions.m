#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "NSAttributedStringAdditions.h"
#import "NSColorAdditions.h"
#import "NSStringAdditions.h"

static NSConditionLock *renderingFragmentLock = nil;
static WebView *fragmentWebView = nil;

@implementation NSAttributedString (NSAttributedStringHTMLAdditions)
+ (id) attributedStringWithHTMLFragment:(NSString *) fragment baseURL:(NSURL *) url {
	extern NSConditionLock *renderingFragmentLock;
	extern WebView *fragmentWebView;

	NSParameterAssert( fragment != nil );

	if( ! renderingFragmentLock )
		renderingFragmentLock = [[NSConditionLock alloc] initWithCondition:2];
	fragmentWebView = nil;

	[renderingFragmentLock lockWhenCondition:2];
	[renderingFragmentLock unlockWithCondition:0];

	[NSThread detachNewThreadSelector:@selector( renderHTMLFragment: ) toTarget:self withObject:[NSDictionary dictionaryWithObjectsAndKeys:fragment, @"fragment", url, @"url", nil]];

	[renderingFragmentLock lockWhenCondition:1];

	id result = [[[self alloc] initWithAttributedString:[(id <WebDocumentText>)[[[fragmentWebView mainFrame] frameView] documentView] attributedString]] autorelease];

	[renderingFragmentLock unlockWithCondition:2];

	return result;
}

+ (void) renderHTMLFragment:(NSDictionary *) info {
	extern WebView *fragmentWebView;
	extern NSConditionLock *renderingFragmentLock;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	[renderingFragmentLock lockWhenCondition:0];

	[NSThread setThreadPriority:1.0];

	NSString *fragment = [info objectForKey:@"fragment"];
	NSURL *url = [info objectForKey:@"url"];

	fragmentWebView = [[WebView alloc] initWithFrame:NSMakeRect( 0., 0., 300., 100. ) frameName:nil groupName:nil];
	[fragmentWebView setFrameLoadDelegate:self];
	[[fragmentWebView mainFrame] loadHTMLString:[NSString stringWithFormat:@"<font color=\"#01fe02\">%@</font>", fragment] baseURL:url];

	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];

	[renderingFragmentLock lockWhenCondition:2];
	[renderingFragmentLock unlockWithCondition:2];

	[fragmentWebView release];
	fragmentWebView = nil;

	[pool release];
}

+ (void) webView:(WebView *) sender didFinishLoadForFrame:(WebFrame *) frame {
	extern NSConditionLock *renderingFragmentLock;
	[renderingFragmentLock unlockWithCondition:1];
}

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
		NSDictionary *dict = [self attributesAtIndex:limitRange.location longestEffectiveRange:&effectiveRange inRange:limitRange];
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