@interface CQUnreadCountView : UIView {
	NSUInteger _normalCount;
	NSUInteger _importantCount;
	BOOL _highlighted;
}
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
@property (nonatomic) NSUInteger count;
@property (nonatomic) NSUInteger importantCount;
@end
