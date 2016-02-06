#import "NSMethodSignatureAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSMethodSignature (NSMethodSignatureAdditions)
+ (instancetype __nullable) methodSignatureWithReturnAndArgumentTypes:(const char *) retType, ... {
	NSMutableString *types = [[NSMutableString alloc] initWithFormat:@"%s@:", retType];

	char *type = NULL;
	va_list strings;

	va_start( strings, retType );

	while( ( type = va_arg( strings, char * ) ) ) {
		NSString *typeString = @(type);
		if( ! typeString.length ) abort();
		[types appendString:typeString];
	}

	va_end( strings );

	const char *typesCString = [types UTF8String];
	if( ! typesCString ) abort();
	return [self signatureWithObjCTypes:typesCString];
}
@end

NS_ASSUME_NONNULL_END
