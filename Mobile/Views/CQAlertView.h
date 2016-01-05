NS_ASSUME_NONNULL_BEGIN

@class CQAlertView;

@protocol CQAlertViewDelegate <NSObject>
@optional
- (void) alertView:(CQAlertView *) alertView clickedButtonAtIndex:(NSInteger) buttonIndex;
@end

@interface CQAlertView : NSObject
@property NSInteger tag;

@property (nullable, weak) id <CQAlertViewDelegate> delegate;
@property (copy) NSString *title;
@property (nullable, copy) NSString *message;

@property NSInteger cancelButtonIndex;

- (NSInteger) addButtonWithTitle:(nullable NSString *) title;
- (nullable NSString *) buttonTitleAtIndex:(NSInteger) buttonIndex;
- (void) dismissWithClickedButtonIndex:(NSInteger) buttonIndex animated:(BOOL) animated;

// shows popup alert animated.
- (void) show;

- (void) addTextFieldWithPlaceholder:(NSString *__nullable) placeholder andText:(NSString *__nullable) text;
- (void) addSecureTextFieldWithPlaceholder:(NSString *) placeholder;
- (nullable UITextField *)textFieldAtIndex:(NSInteger) textFieldIndex;
@end

NS_ASSUME_NONNULL_END
