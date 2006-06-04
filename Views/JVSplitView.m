#import "JVSplitView.h"
#import "NSImageAdditions.h"

@implementation JVSplitView
- (NSString *) stringWithSavedPosition {
	NSMutableString *result = [NSMutableString string];
	NSEnumerator *subviews = [[self subviews] objectEnumerator];
	NSView *subview = nil;

	while( ( subview = [subviews nextObject] ) ) {
		if( [result length] ) [result appendString:@";"];
		[result appendString:NSStringFromRect( [subview frame] )];
	}

	return result;
}

- (void) setPositionFromString:(NSString *) string {
	if( ! [string length] ) return;

	NSEnumerator *subviews = [[self subviews] objectEnumerator];
	NSEnumerator *frames = [[string componentsSeparatedByString:@";"] objectEnumerator];
	NSView *subview = nil;
	NSString *frame = nil;

	while( ( subview = [subviews nextObject] ) && ( frame = [frames nextObject] ) ) {
		NSRect rect = NSRectFromString( frame );
		if( [self isVertical] ) [subview setFrame:NSMakeRect( NSMinX( rect ), NSMinY( [subview frame] ), NSWidth( rect ), NSHeight( [subview frame] ) )];
		else [subview setFrame:NSMakeRect( NSMinX( [subview frame] ), NSMinY( rect ), NSWidth( [subview frame] ), NSHeight( rect ) )];
	}

	[self adjustSubviews];
}

- (void) savePositionUsingName:(NSString *) name {
	NSParameterAssert( name != nil );
	NSParameterAssert( [name length] > 0 );

	[[NSUserDefaults standardUserDefaults] setObject:[self stringWithSavedPosition] forKey:name];
}

- (BOOL) setPositionUsingName:(NSString *) name {
	NSParameterAssert( name != nil );
	NSParameterAssert( [name length] > 0 );

	NSString *sizes = [[NSUserDefaults standardUserDefaults] objectForKey:name];
	if( [sizes length] ) {
		[self setPositionFromString:sizes];
		return YES;
	}

	return NO;
}

#pragma amrk -

- (void) setMainSubviewIndex:(long) index {
	_mainSubviewIndex = index;
}

- (BOOL) mainSubviewIndex {
	return _mainSubviewIndex;
}

#pragma amrk -

- (void) resetCursorRects {
	if( ! [self isPaneSplitter] )
		[super resetCursorRects];
}

- (float) dividerThickness {
	if( ! [self isVertical] ) return 10.;
	return [super dividerThickness];
}

- (void) drawDividerInRect:(NSRect) rect {
	if( ! [self isVertical] ) {
		rect.origin.y += 10.;
		[[NSImage imageNamed:@"splitviewDividerBackground"] tileInRect:rect];
		if( ! [self isPaneSplitter] )
			[[NSImage imageNamed:@"splitviewDimple"] compositeToPoint:NSMakePoint( ( NSWidth( rect ) / 2. ) - 3., rect.origin.y ) operation:NSCompositeCopy];
	} else [super drawDividerInRect:rect];
}
@end