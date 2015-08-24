NS_ASSUME_NONNULL_BEGIN

@interface UIImage (UIImageAdditions)
+ (UIImage *) patternImageWithColor:(UIColor *) color;
- (UIImage *) resizeToSize:(CGSize) size;
@end

NS_ASSUME_NONNULL_END
