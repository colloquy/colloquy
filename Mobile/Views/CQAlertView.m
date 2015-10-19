#import "CQAlertView.h"

NS_ASSUME_NONNULL_BEGIN

@interface CQAlertView ()
@property (atomic, nullable, strong) UIViewController *overlappingPresentationViewController;
@property (atomic, nullable, strong) UIAlertController *alertController;

@end

@implementation CQAlertView {
	NSMutableArray *_textFieldInformation;
}

- (instancetype) init {
	if (!(self = [super init]))
		return nil;

	_textFieldInformation = [[NSMutableArray alloc] init];

	return self;
}

#pragma mark -

- (void) addTextFieldWithPlaceholder:(NSString *__nullable) placeholder andText:(NSString *__nullable) text {
	NSAssert(_textFieldInformation.count + 1 < 3, @"alertView's are limited to a max of 2 textfields as of iOS 5", nil);

	NSMutableDictionary *textFieldInformation = [NSMutableDictionary dictionary];

	if (placeholder.length)
		textFieldInformation[@"placeholder"] = placeholder;
	if (text.length)
		textFieldInformation[@"text"] = text;

	[_textFieldInformation addObject:textFieldInformation];
}

- (void) addSecureTextFieldWithPlaceholder:(NSString *) placeholder {
	NSAssert(_textFieldInformation.count + 1 < 3, @"alertView's are limited to a max of 2 textfields as of iOS 5", nil);

	NSMutableDictionary *textFieldInformation = [NSMutableDictionary dictionary];

	if (placeholder.length)
		textFieldInformation[@"placeholder"] = placeholder;
	textFieldInformation[@"secure"] = @(YES);

	[_textFieldInformation addObject:textFieldInformation];
}

- (UITextField *__nullable) textFieldAtIndex:(NSInteger) textFieldIndex {
	return self.alertController.textFields[textFieldIndex];
}

- (void) show {
	// The overlapping view is needed to work around the following iOS 8(.1-only?) bug on iPad:
	// • If the root Split View Controller is configured to allow the main view overlap its detail views and we
	// present an action sheet from a point on screen that results in the popover rect overlapping the main view,
	// the z-index will be incorrect and the action sheet will be clipped by the main view.
	self.overlappingPresentationViewController = [[UIViewController alloc] init];
	self.overlappingPresentationViewController.view.frame = [UIApplication sharedApplication].keyWindow.frame;
	self.overlappingPresentationViewController.view.backgroundColor = [UIColor clearColor];

	[[UIApplication sharedApplication].keyWindow addSubview:self.overlappingPresentationViewController.view];

	self.alertController = [UIAlertController alertControllerWithTitle:self.title message:self.message preferredStyle:UIAlertControllerStyleAlert];

	for (NSDictionary *textFieldInformation in _textFieldInformation) {
		[self.alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
			textField.text = textFieldInformation[@"text"];
			textField.placeholder = textFieldInformation[@"placeholder"];
			textField.secureTextEntry = !!textFieldInformation[@"secure"];
		}];
	}

	for (NSInteger i = 0; i < self.numberOfButtons; i++) {
		NSString *title = [self buttonTitleAtIndex:i];
		UIAlertActionStyle style = UIAlertActionStyleDefault;
		if (i == self.cancelButtonIndex) style = UIAlertActionStyleCancel;

		UIAlertAction *action = [UIAlertAction actionWithTitle:title style:style handler:^(UIAlertAction *selectedAction) {
			[self _dismissWithClickAtIndex:i];
		}];

		[self.alertController addAction:action];

		if (i == self.cancelButtonIndex && [self.alertController respondsToSelector:@selector(setPreferredAction:)])
			self.alertController.preferredAction = action;
	}

	CGRect rect = CGRectZero;
	rect.size = CGSizeMake(1., 1.);
	rect.origin = [UIApplication sharedApplication].keyWindow.center;
	self.alertController.popoverPresentationController.sourceRect = rect;
	self.alertController.popoverPresentationController.sourceView = self.overlappingPresentationViewController.view;

	UITextField *textField = self.alertController.textFields.firstObject;
	[textField becomeFirstResponder];

	[self.overlappingPresentationViewController presentViewController:self.alertController animated:YES completion:nil];
}

- (void) dismissWithClickedButtonIndex:(NSInteger) buttonIndex animated:(BOOL) animated {
	__weak __typeof__((self)) weakSelf = self;
	[self.alertController dismissViewControllerAnimated:YES completion:^{
		__strong __typeof__((weakSelf)) strongSelf = weakSelf;
		[strongSelf _dismissWithClickAtIndex:buttonIndex];
	}];
}

- (void) _dismissWithClickAtIndex:(NSInteger) buttonIndex {
	__weak __typeof__((self)) weakSelf = self;
	[[NSOperationQueue mainQueue] addOperationWithBlock:^{
		__strong __typeof__((weakSelf)) strongSelf = weakSelf;
		[strongSelf.overlappingPresentationViewController.view removeFromSuperview];
		[strongSelf.overlappingPresentationViewController removeFromParentViewController];
		strongSelf.overlappingPresentationViewController = nil;

		__strong id <UIAlertViewDelegate> delegate = strongSelf.delegate;
		if ([delegate respondsToSelector:@selector(alertView:clickedButtonAtIndex:)])
			[delegate alertView:strongSelf clickedButtonAtIndex:buttonIndex];

		strongSelf.alertController = nil;
	}];
}
@end

NS_ASSUME_NONNULL_END
