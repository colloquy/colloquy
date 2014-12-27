@class UIColor;

@interface UIImage (UIImageAdditions)
+ (UIImage *) patternImageWithColor:(UIColor *) color;
- (UIImage *) resizeToSize:(CGSize) size;
@end
