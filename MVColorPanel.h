#import <Cocoa/Cocoa.h>

@interface MVColorPanel : NSColorPanel {
	NSMatrix *destination;
}

@end

@interface NSObject (MVColorPanelResponderMethod)
- (void) changeBackgroundColor:(id) sender;
@end
