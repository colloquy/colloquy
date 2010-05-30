#import "CQAlertView.h"

#define TextFieldHorizontalMargin 20
#define TextFieldHeight 25
#define TextFieldHeightWithSeparator 35

@implementation CQAlertView
- (id) init {
	if (!(self = [super init]))
		return nil;

	[self performPrivateSelector:@"setGroupsTextFields:" withBoolean:YES];

	return self;
}

- (void) dealloc {
	[_userInfo release];

	[super dealloc];
}

#pragma mark -

@synthesize userInfo = _userInfo;

#pragma mark -

- (void) addTextFieldWithPlaceholder:(NSString *) placeholder andText:(NSString *) text {
	[self performPrivateSelector:@"addTextFieldWithValue:label:" withObject:text withObject:placeholder];
}

- (void) addSecureTextFieldWithPlaceholder:(NSString *) placeholder {
	UITextField *textField = [self performPrivateSelector:@"addTextFieldWithValue:label:" withObject:nil withObject:placeholder];
	textField.secureTextEntry = YES;
}
@end
