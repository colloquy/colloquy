#import <AppKit/NSView.h>

@interface JVSideStatusView : NSView {
	IBOutlet NSSplitView *splitView;
	float _clickOffset;
	BOOL _insideResizeArea;
}
@end
