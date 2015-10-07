#import "CQAlertView.h"

NS_ASSUME_NONNULL_BEGIN

@interface CQAlertView ()
@property (atomic, nullable, strong) UIViewController *overlappingPresentationViewController;
@property (atomic, nullable, strong) UIAlertController *alertController;
@property (atomic, nullable, strong) id me;

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

- (void) _updateTextFieldsForDisplay {
	if ([UIDevice currentDevice].isSystemEight)
		return;

	if (_textFieldInformation.count == 0)
		self.alertViewStyle = UIAlertViewStyleDefault;
	else if (_textFieldInformation.count == 1)
		self.alertViewStyle = UIAlertViewStylePlainTextInput;
	else self.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;

	for (NSUInteger i = 0; i < _textFieldInformation.count; i++) {
		NSDictionary *textFieldInformation = _textFieldInformation[i];
		UITextField *textField = [self textFieldAtIndex:i];

		textField.placeholder = textFieldInformation[@"placeholder"];
		textField.text = textFieldInformation[@"text"];
		textField.secureTextEntry = !!textFieldInformation[@"secure"];
	}
}

- (void) addTextFieldWithPlaceholder:(NSString *__nullable) placeholder andText:(NSString *__nullable) text {
	NSAssert(_textFieldInformation.count + 1 < 3, @"alertView's are limited to a max of 2 textfields as of iOS 5", nil);

	NSMutableDictionary *textFieldInformation = [NSMutableDictionary dictionary];

	if (placeholder.length)
		textFieldInformation[@"placeholder"] = placeholder;
	if (text.length)
		textFieldInformation[@"text"] = text;

	[_textFieldInformation addObject:textFieldInformation];

	[self _updateTextFieldsForDisplay];
}

- (void) addSecureTextFieldWithPlaceholder:(NSString *) placeholder {
	NSAssert(_textFieldInformation.count + 1 < 3, @"alertView's are limited to a max of 2 textfields as of iOS 5", nil);

	NSMutableDictionary *textFieldInformation = [NSMutableDictionary dictionary];

	if (placeholder.length)
		textFieldInformation[@"placeholder"] = placeholder;
	textFieldInformation[@"secure"] = @(YES);

	[_textFieldInformation addObject:textFieldInformation];

	[self _updateTextFieldsForDisplay];
}

- (UITextField *__nullable) textFieldAtIndex:(NSInteger) textFieldIndex {
	if (![UIDevice currentDevice].isSystemEight)
		return [super textFieldAtIndex:textFieldIndex];
	return self.alertController.textFields[textFieldIndex];
}

- (void) show {
	if (![UIDevice currentDevice].isSystemEight) {
		if (_textFieldInformation.count) {
			UITextField *textField = [self textFieldAtIndex:0];
			[textField becomeFirstResponder];
		}

		[super show];
		return;
	}

	self.me = self;

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

		__weak __typeof__((self)) weakSelf = self;
		[self.alertController addAction:[UIAlertAction actionWithTitle:title style:style handler:^(UIAlertAction *action) {
			__strong __typeof__((weakSelf)) strongSelf = weakSelf;
			[strongSelf.overlappingPresentationViewController.view removeFromSuperview];
			[strongSelf.delegate alertView:strongSelf clickedButtonAtIndex:i];

			strongSelf.alertController = nil;
			strongSelf.me = nil;
		}]];
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
	if (![UIDevice currentDevice].isSystemEight)
		[super dismissWithClickedButtonIndex:buttonIndex animated:animated];
	else {
		__weak __typeof__((self)) weakSelf = self;
		[self.alertController dismissViewControllerAnimated:YES completion:^{
			__strong __typeof__((weakSelf)) strongSelf = weakSelf;
			[strongSelf.overlappingPresentationViewController.view removeFromSuperview];
			strongSelf.alertController = nil;
			strongSelf.overlappingPresentationViewController = nil;
			strongSelf.me = nil;
		}];
	}
}
@end

NS_ASSUME_NONNULL_END
