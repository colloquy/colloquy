@interface CQAlertView : UIAlertView {
	id _userInfo;

	BOOL _showingKeyboard;
	NSMutableArray *_inputFields;
}

@property (nonatomic, retain) id userInfo;
@property (nonatomic, readonly) NSArray *inputFields;

- (void) addTextField:(UITextField *) textField;
- (void) addTextFieldWithPlaceholder:(NSString *) placeholder tag:(NSInteger) tag;
- (void) addTextFieldWithPlaceholder:(NSString *) placeholder tag:(NSInteger) tag secureTextEntry:(BOOL) secureTextEntry;
@end
