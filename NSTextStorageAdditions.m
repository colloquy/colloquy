#import "NSTextStorageAdditions.h"

@implementation NSTextStorage (NSTextStorageAdditions)
- (NSColor *) backgroundColor {
	return [self attribute:NSBackgroundColorAttributeName atIndex:0 effectiveRange:NULL];
}

- (void) setBackgroundColor:(NSColor *) color {
	if( ! color ) [self removeAttribute:NSBackgroundColorAttributeName range:NSMakeRange( 0, [self length] )];
	else [self addAttribute:NSBackgroundColorAttributeName value:color range:NSMakeRange( 0, [self length] )];
}

- (NSString *) hyperlink {
	id link = [self attribute:NSLinkAttributeName atIndex:0 effectiveRange:NULL];
	if( [link isKindOfClass:[NSURL class]] ) return [link absoluteString];
	else if( [link isKindOfClass:[NSString class]] ) return link;
	return nil;
}

- (void) setHyperlink:(NSString *) link {
	if( ! [link length] ) [self removeAttribute:NSLinkAttributeName range:NSMakeRange( 0, [self length] )];
	else [self addAttribute:NSLinkAttributeName value:link range:NSMakeRange( 0, [self length] )];
}

- (BOOL) boldState {
	NSFont *font = [self attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
	int traits = [[NSFontManager sharedFontManager] traitsOfFont:font];
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
	int traits = [[NSFontManager sharedFontManager] traitsOfFont:font];
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
	if( ! [classes count] ) [self removeAttribute:@"CSSClasses" range:NSMakeRange( 0, [self length] )];
	else [self addAttribute:@"CSSClasses" value:[NSMutableSet setWithArray:classes] range:NSMakeRange( 0, [self length] )];
}
@end