@interface CQAlertView : UIAlertView {
	id _userInfo;
}

@property (nonatomic, retain) id userInfo;

- (void) addTextFieldWithPlaceholder:(NSString *) placeholder andText:(NSString *) text;
- (void) addSecureTextFieldWithPlaceholder:(NSString *) placeholder;
@end
