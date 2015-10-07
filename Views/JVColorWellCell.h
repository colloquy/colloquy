extern NSString *JVColorWellCellColorDidChangeNotification;

@interface JVColorWellCell : NSButtonCell {
	NSColor *_color;
	BOOL _showsWebValue;
	BOOL _releasing;
}
- (void) deactivate;
- (void) activate:(BOOL) exclusive;
@property (readonly, getter=isActive) BOOL active;

- (void) takeColorFrom:(id) sender;

@property (strong) NSColor *color;

@property BOOL showsWebValue;
@end
