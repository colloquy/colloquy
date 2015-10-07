#import "NSCharacterSetAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSCharacterSet (Additions)
+ (NSCharacterSet *) illegalXMLCharacterSet {
	static NSMutableCharacterSet *illegalSet = nil;
	if (!illegalSet) {
		illegalSet = [[NSCharacterSet characterSetWithRange:NSMakeRange( 0, 0x1f )] mutableCopy];

		[illegalSet removeCharactersInRange:NSMakeRange( 0x09, 1 )];

		[illegalSet addCharactersInRange:NSMakeRange( 0x7f, 1 )];
		[illegalSet addCharactersInRange:NSMakeRange( 0xfffe, 1 )];
		[illegalSet addCharactersInRange:NSMakeRange( 0xffff, 1 )];
	}

	return [illegalSet copy];
}

+ (NSCharacterSet *) cq_encodedXMLCharacterSet {
	static NSCharacterSet *specialSet = nil;
	if (!specialSet) {
		specialSet = [NSCharacterSet characterSetWithCharactersInString:@"&<>\"'"];;
	}
	return specialSet;
}
@end

NS_ASSUME_NONNULL_END
