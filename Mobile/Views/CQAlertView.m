#import "CQAlertView.h"

@implementation CQAlertView
- (id) init {
	if (!(self = [super init]))
		return nil;

	[self performPrivateSelector:@"setGroupsTextFields:" withBoolean:YES];

	return self;
}

#pragma mark -

- (void) addTextFieldWithPlaceholder:(NSString *) placeholder andText:(NSString *) text {
	[self performPrivateSelector:@"addTextFieldWithValue:label:" withObject:text withObject:placeholder];
}

- (void) addSecureTextFieldWithPlaceholder:(NSString *) placeholder {
	UITextField *textField = [self performPrivateSelector:@"addTextFieldWithValue:label:" withObject:nil withObject:placeholder];
	textField.secureTextEntry = YES;
}
@end
