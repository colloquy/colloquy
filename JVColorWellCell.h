#import <AppKit/NSButtonCell.h>

@class NSColor;

extern NSString *JVColorWellCellColorDidChangeNotification;

@interface JVColorWellCell : NSButtonCell {
	NSColor *_color;
	BOOL _showsWebValue;
	BOOL _releasing;
}
- (void) deactivate;
- (void) activate:(BOOL) exclusive;
- (BOOL) isActive;

- (void) takeColorFrom:(id) sender;

- (void) setColor:(NSColor *) color;
- (NSColor *) color;

- (void) setShowsWebValue:(BOOL) web;
- (BOOL) showsWebValue;
@end
