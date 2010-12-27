@interface CQDualButtonCell : NSCell {
@private
	NSButtonCell *_leftButtonCell;
	NSButtonCell *_rightButtonCell;
	BOOL _hideLeftButton;

	BOOL _mouseoverInLeftButton;
	BOOL _mouseoverInRightButton;
}
@property (nonatomic, readonly) NSButtonCell *leftButtonCell;
@property (nonatomic, readonly) NSButtonCell *rightButtonCell;
@property (nonatomic) BOOL hidesLeftButton;

- (void) mouseEntered:(NSEvent *) event;
- (void) mouseExited:(NSEvent *) event;
- (void) addTrackingAreasForView:(NSView *) controlView inRect:(NSRect) cellFrame withUserInfo:(NSDictionary *) userInfo mouseLocation:(NSPoint) mouseLocation;
@end
