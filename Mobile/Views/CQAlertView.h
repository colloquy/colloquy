@interface CQAlertView : UIAlertView {
@private
	NSMutableArray *_textFieldInformation;
	UIAlertController *_alertController;
}
- (void) addTextFieldWithPlaceholder:(NSString *) placeholder andText:(NSString *) text;
- (void) addSecureTextFieldWithPlaceholder:(NSString *) placeholder;
@end
