extern NSString *CQDualButtonLeftDictionaryKey;
extern NSString *CQDualButtonRightDictionaryKey;

extern NSString *CQMouseStateDefaultKey;
extern NSString *CQMouseStateHoverKey;
extern NSString *CQMouseStateClickKey;

@interface CQButtonCell : NSCell {
@private
	NSButtonCell *_leftButtonCell;
	NSButtonCell *_rightButtonCell;
	BOOL _hideLeftButton;

	NSInteger _leftButtonMouseState;
	NSInteger _rightButtonMouseState;

	NSDictionary *_mouseStates;
}
@property (nonatomic, readonly) NSButtonCell *leftButtonCell;
@property (nonatomic, readonly) NSButtonCell *rightButtonCell;
@property (nonatomic) BOOL hidesLeftButton;
@property (nonatomic, retain) NSDictionary *mouseStates;
@end
