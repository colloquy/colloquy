#import "CQTextView.h"

@implementation CQTextView
- (instancetype) initWithFrame:(CGRect) frame {
	if (!(self = [super initWithFrame:frame]))
		return nil;

	self.layer.masksToBounds = YES;
	self.layer.cornerRadius = 10.;

	_placeholder = [[UILabel alloc] initWithFrame:CGRectZero];
	_placeholder.textColor = [UIColor lightGrayColor];
	_placeholder.backgroundColor = [UIColor clearColor];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textViewChanged:) name:UITextViewTextDidChangeNotification object:nil];

	[self addSubview:_placeholder];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -

- (void) setText:(NSString *) text {
	[super setText:text];

	if (text.length)
		_placeholder.alpha = 0.;
	else _placeholder.alpha = 1.;
}

- (NSString *) placeholder {
	return _placeholder.text;
}

- (void) setPlaceholder:(NSString *) placeholder {
	_placeholder.text = placeholder;
	if (self.text.length)
		_placeholder.alpha = 0.;
	else if (_placeholder.text.length) _placeholder.alpha = _placeholder.text.length;

	[_placeholder sizeToFit];

	CGRect frame = _placeholder.frame;
	CGRect caretFrame = [self caretRectForPosition:self.beginningOfDocument];
	frame.origin.y = CGRectGetMinY(caretFrame);
	frame.origin.x = CGRectGetMaxX(caretFrame);
	_placeholder.frame = frame;
	
}

#pragma mark -

- (void) textViewChanged:(NSNotification *) notification {
	_placeholder.alpha = !self.text.length;
}
@end
