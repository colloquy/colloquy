#import <AppKit/NSView.h>

@interface JVSideStatusView : NSView {
	IBOutlet NSSplitView *splitView;
	CGFloat _clickOffset;
	BOOL _insideResizeArea;
}
@end
