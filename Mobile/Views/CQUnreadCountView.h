NS_ASSUME_NONNULL_BEGIN

@interface CQUnreadCountView : UIView
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
@property (nonatomic) NSUInteger count;
@property (nonatomic) NSUInteger importantCount;
@end

NS_ASSUME_NONNULL_END
