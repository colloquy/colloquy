extern NSString *CQDualButtonLeftDictionaryKey;
extern NSString *CQDualButtonRightDictionaryKey;

extern NSString *CQMouseStateDefaultKey;
extern NSString *CQMouseStateHoverKey;
extern NSString *CQMouseStateClickKey;

@interface CQDualButtonCell : NSCell {
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

- (void) mouseEntered:(NSEvent *) event;
- (void) mouseExited:(NSEvent *) event;
- (void) addTrackingAreasForView:(NSView *) controlView inRect:(NSRect) cellFrame withUserInfo:(NSDictionary *) userInfo mouseLocation:(NSPoint) mouseLocation;
@end
