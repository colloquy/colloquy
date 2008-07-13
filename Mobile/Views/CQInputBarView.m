#import "CQInputBarView.h"

static UIImage *backgroundImage = nil;

@implementation CQInputBarView
- (id) initWithFrame:(CGRect) frame {
	if( ! backgroundImage )
		backgroundImage = [[UIImage alloc] initWithContentsOfFile:@"/Applications/MobileSMS.app/MessageEntryBG.png"];
	self = [super initWithFrame:frame];
	[self setOpaque:YES];
	return self;
}

- (void) drawRect:(CGRect) rect {
	[backgroundImage drawAsPatternInRect:[self bounds]];
	[super drawRect:rect];
}
@end
