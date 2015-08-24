// As nice as it would be to have this as a subview in another view, that won't work, because, iOS 7 blurring is only applied to
// UIToolbar and UINavigationBar subclasses, not arbitrary UIView subclasses.

#import "CQNavigationToolbar.h"

NS_ASSUME_NONNULL_BEGIN

@interface CQNavigationToolbar ()
@property (nonatomic, strong) UIImageView *bottomLineView;
@end

@implementation  CQNavigationToolbar
- (instancetype) initWithFrame:(CGRect) frame {
	if (!(self = [super initWithFrame:frame]))
		return nil;

	[self cq_commonInitialization];
	
	return self;
}

- (__nullable instancetype) initWithCoder:(NSCoder *) coder {
	if (!(self = [super initWithCoder:coder]))
		return nil;

	[self cq_commonInitialization];

	return self;
}

- (void) cq_commonInitialization {
	self.backgroundColor = [UIColor colorWithWhite:(248. / 244.) alpha:1.];

	_bottomLineView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"pixel-172.png"]];

	[self addSubview:_bottomLineView];
}

#pragma mark -

- (void) layoutSubviews {
	[super layoutSubviews];

	for (UIView *view in self.subviews) {
		CGRect frame = view.frame;

		// checking if width == view width is a quick sanity check to avoid messing with the background view, while still
		// ensuring that the buttons are properly positioned within the toolbar (that is,
		if (view != _bottomLineView && CGRectGetWidth(frame) == CGRectGetWidth(self.frame))
			continue;

		CGRect statusBarFrame = [UIApplication sharedApplication].statusBarFrame;
		statusBarFrame = [[UIApplication sharedApplication].delegate.window convertRect:statusBarFrame toView:self];

		CGFloat offset = statusBarFrame.size.height;
		frame.size.height = CGRectGetHeight(self.frame);
		frame.origin.y = floorf((((CGRectGetHeight(self.frame) + offset) / 2.) - (CGRectGetHeight(frame) / 2.)));
		view.frame = frame;
	}

	CGFloat height = _bottomLineView.image.size.height / [UIScreen mainScreen].scale;
	_bottomLineView.frame = CGRectMake(0., CGRectGetHeight(self.frame), CGRectGetWidth(self.frame), height);

	[self bringSubviewToFront:_bottomLineView];
}
@end

NS_ASSUME_NONNULL_END
