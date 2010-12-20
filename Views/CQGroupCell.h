@interface CQGroupCell : NSCell {
@private
	NSUInteger _unansweredActivityCount;
}
@property (nonatomic) NSUInteger unansweredActivityCount;
@end
