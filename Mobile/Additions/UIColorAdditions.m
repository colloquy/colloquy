#import "UIColorAdditions.h"

@implementation UIColor (Additions)
+ (UIColor *) colorFromName:(NSString *) name {
	if (!name.length)
		return nil;

	name = name.lowercaseString;

	if ([name isEqualToString:@"white"])
		return [UIColor whiteColor];
	if ([name isEqualToString:@"ash"])
		return [UIColor colorWithRed:(214. / 255.) green:(214. / 255.) blue:(214. / 255.) alpha:1.];
	if ([name isEqualToString:@"grey"])
		return [UIColor colorWithRed:(121. / 255.) green:(121. / 255.) blue:(121. / 255.) alpha:1.];
	if ([name isEqualToString:@"black"])
		return [UIColor blackColor];

	if ([name isEqualToString:@"cyan"])
		return [UIColor colorWithRed:0. green:(252. / 255.) blue:1. alpha:1.];
	if ([name isEqualToString:@"teal"])
		return [UIColor colorWithRed:0. green:(168. / 255.) blue:(170. / 255.) alpha:1.];
	if ([name isEqualToString:@"blue"])
		return [UIColor colorWithRed:(4. / 255.) green:(51. / 255.) blue:1. alpha:1.];
	if ([name isEqualToString:@"navy"])
		return [UIColor colorWithRed:0. green:(19. / 255.) blue:(121. / 255.) alpha:1.];

	if ([name isEqualToString:@"yellow"])
		return [UIColor colorWithRed:(254. / 255.) green:(251. / 255.) blue:0. alpha:1.];
	if ([name isEqualToString:@"orange"])
		return [UIColor colorWithRed:1. green:(124. / 255.) blue:0. alpha:1.];
	if ([name isEqualToString:@"green"])
		return [UIColor colorWithRed:0. green:(247. / 255.) blue:0. alpha:1.];
	if ([name isEqualToString:@"forest"])
		return [UIColor colorWithRed:0. green:(166. / 255.) blue:0. alpha:1.];

	if ([name isEqualToString:@"red"])
		return [UIColor colorWithRed:1. green:(38. / 255.) blue:0. alpha:1.];
	if ([name isEqualToString:@"maroon"])
		return [UIColor colorWithRed:(122. / 255.) green:(12. / 255.) blue:0. alpha:1.];
	if ([name isEqualToString:@"magenta"])
		 return [UIColor colorWithRed:1. green:(64. / 255.) blue:1. alpha:1.];
	if ([name isEqualToString:@"purple"])
		return [UIColor colorWithRed:(172. / 255.) green:(39. / 255.) blue:(169. / 255.) alpha:1.];

	return nil;
}
@end
