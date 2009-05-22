#import "NSTextStorageAdditions.h"

@implementation NSTextStorage (NSTextStorageAdditions)
- (NSColor *) backgroundColor {
	id color = [self attribute:NSBackgroundColorAttributeName atIndex:0 effectiveRange:NULL];
	if( [color isKindOfClass:[NSColor class]] ) return color;
	return (id)[NSNull null];
}

- (void) setBackgroundColor:(NSColor *) color {
	if( ! color || ! [color isKindOfClass:[NSColor class]] ) [self removeAttribute:NSBackgroundColorAttributeName range:NSMakeRange( 0, [self length] )];
	else [self addAttribute:NSBackgroundColorAttributeName value:color range:NSMakeRange( 0, [self length] )];
}

- (NSString *) hyperlink {
	id link = [self attribute:NSLinkAttributeName atIndex:0 effectiveRange:NULL];
	if( [link isKindOfClass:[NSURL class]] ) return [link absoluteString];
	else if( [link isKindOfClass:[NSString class]] ) return link;
	return (id)[NSNull null];
}

- (void) setHyperlink:(NSString *) link {
	if( ! [link isKindOfClass:[NSString class]] || ! [link length] ) [self removeAttribute:NSLinkAttributeName range:NSMakeRange( 0, [self length] )];
	else [self addAttribute:NSLinkAttributeName value:link range:NSMakeRange( 0, [self length] )];
}

- (BOOL) boldState {
	NSFont *font = [self attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
	NSFontTraitMask traits = [[NSFontManager sharedFontManager] traitsOfFont:font];
	return ( traits & NSBoldFontMask );
}

- (void) setBoldState:(BOOL) bold {
	NSFont *font = [self attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
	if( bold ) font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSBoldFontMask];
	else font = [[NSFontManager sharedFontManager] convertFont:font toNotHaveTrait:NSBoldFontMask];
	if( font ) [self addAttribute:NSFontAttributeName value:font range:NSMakeRange( 0, [self length] )];
}

- (BOOL) italicState {
	NSFont *font = [self attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
	NSFontTraitMask traits = [[NSFontManager sharedFontManager] traitsOfFont:font];
	return ( traits & NSItalicFontMask );
}

- (void) setItalicState:(BOOL) italic {
	NSFont *font = [self attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
	if( bold ) font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSItalicFontMask];
	else font = [[NSFontManager sharedFontManager] convertFont:font toNotHaveTrait:NSItalicFontMask];
	if( font ) [self addAttribute:NSFontAttributeName value:font range:NSMakeRange( 0, [self length] )];
}

- (BOOL) underlineState {
	return [[self attribute:NSUnderlineStyleAttributeName atIndex:0 effectiveRange:NULL] boolValue];
}

- (void) setUnderlineState:(BOOL) underline {
	if( ! underline ) [self removeAttribute:NSUnderlineStyleAttributeName range:NSMakeRange( 0, [self length] )];
	else [self addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithBool:1] range:NSMakeRange( 0, [self length] )];
}

- (NSArray *) styleClasses {
	return [[self attribute:@"CSSClasses" atIndex:0 effectiveRange:NULL] allObjects];
}

- (void) setStyleClasses:(NSArray *) classes {
	if( ! [classes isKindOfClass:[NSArray class]] || ! [classes count] ) [self removeAttribute:@"CSSClasses" range:NSMakeRange( 0, [self length] )];
	else [self addAttribute:@"CSSClasses" value:[NSSet setWithArray:classes] range:NSMakeRange( 0, [self length] )];
}

- (NSString *) styleText {
	return [self attribute:@"CSSText" atIndex:0 effectiveRange:NULL];
}

- (void) setStyleText:(NSString *) style {
	if( ! [style isKindOfClass:[NSString class]] || ! [style length] ) [self removeAttribute:@"CSSText" range:NSMakeRange( 0, [self length] )];
	else [self addAttribute:@"CSSText" value:style range:NSMakeRange( 0, [self length] )];
}

- (NSString *) XHTMLStart {
	return [self attribute:@"XHTMLStart" atIndex:0 effectiveRange:NULL];
}

- (void) setXHTMLStart:(NSString *) html {
	if( ! [html isKindOfClass:[NSString class]] ) [self removeAttribute:@"XHTMLStart" range:NSMakeRange( 0, [self length] )];
	else [self addAttribute:@"XHTMLStart" value:html range:NSMakeRange( 0, [self length] )];
}

- (NSString *) XHTMLEnd {
	return [self attribute:@"XHTMLEnd" atIndex:0 effectiveRange:NULL];
}

- (void) setXHTMLEnd:(NSString *) html {
	if( ! [html isKindOfClass:[NSString class]] ) [self removeAttribute:@"XHTMLEnd" range:NSMakeRange( 0, [self length] )];
	else [self addAttribute:@"XHTMLEnd" value:html range:NSMakeRange( 0, [self length] )];
}
@end
