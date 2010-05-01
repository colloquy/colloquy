#import "CQAlertView.h"

#define TextFieldHorizontalMargin 20
#define TextFieldHeight 25
#define TextFieldHeightWithSeparator 35

@implementation CQAlertView
- (id) init {
	if (!(self = [super init]))
		return nil;

	_inputFields = [[NSMutableArray alloc] initWithCapacity:2];

	[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(repositionAlertView) name:UIDeviceOrientationDidChangeNotification object:nil];

	return self;
}

- (void) dealloc {
	[[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_userInfo release];
	[_inputFields release];

	[super dealloc];
}

#pragma mark -

@synthesize userInfo = _userInfo;
@synthesize inputFields = _inputFields;

#pragma mark -

- (void) layoutSubviews {
	if (!_inputFields.count) {
		[super layoutSubviews];
		return;
	}

	CGFloat yConstant = 0.;
	CGRect rect = self.bounds;
	NSUInteger inputFieldCount = _inputFields.count;
	NSMutableArray *buttons = [[NSMutableArray alloc] initWithCapacity:2];

	self.bounds = CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height + (TextFieldHeightWithSeparator * inputFieldCount));

	Class threePartButton = NSClassFromString(@"UIThreePartButton");
	for (UIView *subview in self.subviews) {
		if ([subview isKindOfClass:[UILabel class]])
			yConstant += subview.bounds.size.height;
		else if ([subview isKindOfClass:threePartButton])
			[buttons addObject:subview];
	}

	// Make sure we finished calculating the title + message label heights (yConstant) before moving the buttons down
	CGFloat verticalButtonOffset = (TextFieldHeightWithSeparator * inputFieldCount);
	for (UIView *button in buttons) {
		rect = button.frame;
		button.frame = CGRectMake(rect.origin.x, rect.origin.y + verticalButtonOffset, rect.size.width, rect.size.height);
	}

	[super layoutSubviews];

	[buttons release];

	UITextField *field = nil;
	CGFloat textFieldWidth = self.bounds.size.width - (TextFieldHorizontalMargin * 2);
	for (NSUInteger i = 0; i < _inputFields.count; i++) {
		field = [_inputFields objectAtIndex:i];
		field.frame = CGRectMake(TextFieldHorizontalMargin, yConstant + ((i + 1) * TextFieldHeightWithSeparator), textFieldWidth, TextFieldHeight);

		[self addSubview:field];
	}
}

#pragma mark -

- (void) addTextField:(UITextField *) textField {
	[_inputFields addObject:textField];
}

- (void) addTextFieldWithPlaceholder:(NSString *) placeholder tag:(NSInteger) tag {
	[self addTextFieldWithPlaceholder:placeholder tag:tag secureTextEntry:NO];
}

- (void) addTextFieldWithPlaceholder:(NSString *) placeholder tag:(NSInteger) tag secureTextEntry:(BOOL) secureTextEntry {
	UITextField *textField = [[UITextField alloc] init];
	textField.tag = tag;
	textField.placeholder = placeholder.length ? placeholder : @"";
	textField.font = [UIFont systemFontOfSize:14];
	textField.backgroundColor = [UIColor whiteColor];
	textField.secureTextEntry = secureTextEntry;
	textField.keyboardAppearance = UIKeyboardAppearanceAlert;

	[self addTextField:textField];

	[textField release];
}

#pragma mark -

- (void) repositionAlertView {
	if (!_inputFields.count)
		return;

	if (UIDeviceOrientationIsPortrait([UIDevice currentDevice].orientation) && [[UIDevice currentDevice] isPadModel])
		return;

	CGFloat alertViewVerticalOffset = ([[UIDevice currentDevice] isPadModel] ? 150. : 5.);

	CGRect frame = self.frame;
	if (_showingKeyboard) {
		frame = CGRectMake(frame.origin.x, frame.origin.y - alertViewVerticalOffset, frame.size.width, frame.size.height);
		[UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
	} else {
		frame = CGRectMake(frame.origin.x, frame.origin.y + alertViewVerticalOffset, frame.size.width, frame.size.height);
		[UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
	}

	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.25];
	[UIView setAnimationBeginsFromCurrentState:YES];

	self.frame = frame;

	[UIView commitAnimations];
}

- (void) keyboardWillShow:(NSNotification *) notification {
	_showingKeyboard = YES;
	[self repositionAlertView];
}

- (void) keyboardWillHide:(NSNotification *) notification {
	_showingKeyboard = NO;
	[self repositionAlertView];
}

#pragma mark -

- (void) show {
	[super show];

	if (_inputFields.count) {
		_showingKeyboard = YES;

		[self performSelector:@selector(repositionAlertView) withObject:nil afterDelay:.5];
		[[_inputFields objectAtIndex:0] performSelector:@selector(becomeFirstResponder) withObject:nil afterDelay:.51];
	}
}
@end
