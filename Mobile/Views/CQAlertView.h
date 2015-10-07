NS_ASSUME_NONNULL_BEGIN

@interface CQAlertView : UIAlertView
- (void) addTextFieldWithPlaceholder:(NSString *__nullable) placeholder andText:(NSString *__nullable) text;
- (void) addSecureTextFieldWithPlaceholder:(NSString *) placeholder;
@end

NS_ASSUME_NONNULL_END
