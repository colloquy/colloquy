@interface CQAlertView : UIAlertView {
@private
	NSMutableArray *_textFieldInformation;
}
- (void) addTextFieldWithPlaceholder:(NSString *) placeholder andText:(NSString *) text;
- (void) addSecureTextFieldWithPlaceholder:(NSString *) placeholder;
@end
