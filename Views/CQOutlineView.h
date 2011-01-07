@interface CQOutlineView : NSOutlineView {
@private
	NSInteger _mouseoverRow;
	NSInteger _mouseoverColumn;
	NSCell *_mouseoverCell;

	NSTimeInterval _lastReloadDataTime;
}
@end
