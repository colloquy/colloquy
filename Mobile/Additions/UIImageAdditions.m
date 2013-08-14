#import "UIImageAdditions.h"

@implementation UIImage (UIImageAdditions)
- (UIImage *) resizeToSize:(CGSize) size {
	CGFloat scale = [UIScreen mainScreen].scale;
	size.width *= scale;
	size.height *= scale;

	@synchronized(self) {
		CGImageRef imageRef = self.CGImage;

#if TARGET_IPHONE_SIMULATOR
		CGImageAlphaInfo alphaInfo = kCGImageAlphaNoneSkipLast;
#else
		CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(imageRef);
#endif

		if (alphaInfo == kCGImageAlphaNone)
            alphaInfo = kCGImageAlphaNoneSkipLast;

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
				bitmap = CGBitmapContextCreate(NULL, size.height, size.width, CGImageGetBitsPerComponent(imageRef), (size_t)(4  * (size.height + 1)), colorSpaceInfo, alphaInfo);
				break;
		}

		CGContextDrawImage(bitmap, CGRectMake(0, 0, size.width, size.height), imageRef);
		CGImageRef newImageRef = CGBitmapContextCreateImage(bitmap);
		UIImage *result = [[UIImage alloc] initWithCGImage:newImageRef scale:[UIScreen mainScreen].scale orientation:self.imageOrientation];

		CGContextRelease(bitmap);
		CGImageRelease(newImageRef);

		return result;
	}
}

@end
