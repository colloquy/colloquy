#import "CQChatInputField.h"

static UIImage *backgroundImage = nil;

@implementation CQChatInputField
- (id) initWithFrame:(CGRect) frame {
	if( ! ( self = [super initWithFrame:frame] ) )
		return nil;

	if( ! backgroundImage )
		backgroundImage = [[UIImage alloc] initWithContentsOfFile:@"/Applications/MobileSMS.app/BalloonInputField.png"];

	[self setAutoCapsType:0]; // no initial caps
	[self setReturnKeyType:7]; // send button
	[self setAutoEnablesReturnKey:YES];

	return self;
}

- (void) drawRect:(CGRect) rect {
	CGRect left = CGRectMake(0., 0., 13., 26.);
	CGRect middle = CGRectMake(13., 0., 1., 26.);
	CGRect right = CGRectMake(14., 0., 17., 26.);
	CDAnonymousStruct4 slices = { left, middle, right };

	[backgroundImage draw3PartImageWithSliceRects:slices inRect:[self bounds]];

	[super drawRect:rect];
}
@end
