#import <AppKit/NSSplitView.h>

@interface JVSideStatusView : NSView {
	IBOutlet NSSplitView *splitView;
	CGFloat _clickOffset;
	BOOL _insideResizeArea;
}
@end
