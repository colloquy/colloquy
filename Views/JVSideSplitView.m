#import "JVSideSplitView.h"

@implementation JVSideSplitView
- (float) dividerThickness {
	return 1.0;
}

- (void) drawDividerInRect:(NSRect) rect {
	[[NSColor colorWithCalibratedWhite:0.65 alpha:1.] set];
	NSRectFill( rect );
}
@end
