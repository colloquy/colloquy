#import <Cocoa/Cocoa.h>

extern NSString *JVColorWellCellColorDidChangeNotification;

@interface JVColorWellCell : NSButtonCell {
	NSColor *_color;
	BOOL _showsWebValue;
	BOOL _releasing;
}
- (instancetype) initTextCell:(NSString *) string;
- (instancetype) initImageCell:(NSImage *) image NS_DESIGNATED_INITIALIZER;
- (void) deactivate;
- (void) activate:(BOOL) exclusive;
@property (readonly, getter=isActive) BOOL active;

- (void) takeColorFrom:(id) sender;

@property (strong) NSColor *color;

@property BOOL showsWebValue;
@end
