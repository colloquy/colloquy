//
//  NSWindow+CQMCoordinateSpaceConversion.m
//  Colloquy
//
//  Created by Alexander Kempgen on 2016-01-06.
//
//

#import "NSWindow+CQMCoordinateSpaceConversion.h"

@implementation NSWindow (CQMCoordinateSpaceConversion)

- (NSPoint)cqm_convertPointToScreen:(NSPoint)pointInWindow {
	NSRect rectInWindow = {pointInWindow, NSZeroSize};
	NSRect rectInScreen = [self convertRectToScreen:rectInWindow];
	return rectInScreen.origin;
}

@end
