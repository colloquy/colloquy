#import "NSSplitViewAdditions.h"
#import <Cocoa/Cocoa.h>

@implementation NSSplitView (NSSplitViewAdditions)
- (NSString *) stringWithSavedPosition {
	NSMutableString *result = [NSMutableString string]; 
	NSEnumerator *subviews = [[self subviews] objectEnumerator];
	NSView *subview = nil;

	while( ( subview = [subviews nextObject] ) ) {
		if( [result length] ) [result appendString:@";"];
		[result appendString:NSStringFromRect( [subview frame] )];
	}

//	NSLog( @"save: %@", result );
	return result;
}

- (void) setPositionFromString:(NSString *) string {
	if( ! [string length] ) return;

	NSEnumerator *subviews = [[self subviews] objectEnumerator];
	NSEnumerator *frames = [[string componentsSeparatedByString:@";"] objectEnumerator];
	NSView *subview = nil;
	NSString *frame = nil;

//	NSLog( @"restore: %@", string );
	while( ( subview = [subviews nextObject] ) ) {
		frame = [frames nextObject];
		if( [frame length] ) [subview setFrame:NSRectFromString( frame )];
		else [subview setFrame:NSZeroRect];
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
@end