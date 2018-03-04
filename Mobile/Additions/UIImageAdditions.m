#import "UIImageAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation UIImage (UIImageAdditions)
+ (UIImage *) patternImageWithColor:(UIColor *) color {
	UIImage *image = nil;
	UIGraphicsBeginImageContext(CGSizeMake(3., 3.)); {
		CGContextRef contextRef = UIGraphicsGetCurrentContext();
		CGContextSetFillColorWithColor(contextRef, color.CGColor);
		CGContextFillRect(contextRef, CGRectMake(0., 0., 3., 3.));
		image = UIGraphicsGetImageFromCurrentImageContext();
	} UIGraphicsEndImageContext();

	return [image resizableImageWithCapInsets:UIEdgeInsetsMake(1., 1., 1., 1.)];
}

- (UIImage *) resizeToSize:(CGSize) size {
	CGFloat scale = [UIScreen mainScreen].nativeScale;
	size.width *= scale;
	size.height *= scale;

	CGImageRef imageRef = self.CGImage;

	CGBitmapInfo alphaInfo = kCGBitmapAlphaInfoMask;

#if TARGET_IPHONE_SIMULATOR
	alphaInfo |= kCGImageAlphaNoneSkipLast;
#else
	alphaInfo |= CGImageGetAlphaInfo(imageRef);
#endif

	if ((alphaInfo & kCGImageAlphaNone) == kCGImageAlphaNone) {
		alphaInfo ^= kCGImageAlphaNone;
		alphaInfo &= kCGImageAlphaNoneSkipLast;
	}

	static CGColorSpaceRef colorSpaceInfo = NULL;
	if (!colorSpaceInfo)
		colorSpaceInfo = CGColorSpaceCreateDeviceRGB();

	CGContextRef bitmap = NULL;

	switch (self.imageOrientation) {
		case UIImageOrientationUp:
		case UIImageOrientationDown:
			bitmap = CGBitmapContextCreate(NULL, size.width, size.height, CGImageGetBitsPerComponent(imageRef), (size_t)(4 * (size.width + 1)), colorSpaceInfo, alphaInfo);
			break;
		default:
			bitmap = CGBitmapContextCreate(NULL, size.height, size.width, CGImageGetBitsPerComponent(imageRef), (size_t)(4 * (size.height + 1)), colorSpaceInfo, alphaInfo);
			break;
	}

	CGContextDrawImage(bitmap, CGRectMake(0, 0, size.width, size.height), imageRef);
	CGImageRef newImageRef = CGBitmapContextCreateImage(bitmap);
	UIImage *result = [[UIImage alloc] initWithCGImage:newImageRef scale:[UIScreen mainScreen].scale orientation:self.imageOrientation];

	CGContextRelease(bitmap);
	CGImageRelease(newImageRef);

	return result;
}

@end

NS_ASSUME_NONNULL_END
