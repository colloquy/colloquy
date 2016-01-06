//
//  NSWindow+CQMCoordinateSpaceConversion.h
//  Colloquy
//
//  Created by Alexander Kempgen on 2016-01-06.
//
//

#import <Cocoa/Cocoa.h>

@interface NSWindow (CQMCoordinateSpaceConversion)

/**
 Converts the point to the screen coordinate system from the window’s coordinate system.
 
 Drop-in replacement for the deprecated -convertBaseToScreen: method.
 
 @param pointInWindow:  A point in the window’s coordinate system.
 @return                A point in the screen’s coordinate system.
*/
- (NSPoint)cqm_convertPointToScreen:(NSPoint)pointInWindow;

@end
