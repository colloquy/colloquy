#import "NSRegularExpressionAdditions.h"

static NSMutableDictionary *dangerousCache = nil;

@implementation NSRegularExpression (Additions)
+ (NSRegularExpression *) cachedRegularExpressionWithPattern:(NSString *) pattern options:(NSRegularExpressionOptions) options error:(NSError *__autoreleasing*) error {
	static dispatch_once_t pred;
	dispatch_once(&pred, ^{
		dangerousCache = [[NSMutableDictionary alloc] init];
	});
	
	return [self _cachedRegularExpressionWithPattern:pattern options:options error:error inCache:dangerousCache];
}

+ (NSRegularExpression *) threadsafeCachedRegularExpressionWithPattern:(NSString *) pattern options:(NSRegularExpressionOptions) options error:(NSError *__autoreleasing*) error {
	return [self _cachedRegularExpressionWithPattern:pattern options:options error:error inCache:[NSThread currentThread].threadDictionary];
}

+ (NSRegularExpression *) _cachedRegularExpressionWithPattern:(NSString *) pattern options:(NSRegularExpressionOptions) options error:(NSError *__autoreleasing*) error inCache:(NSMutableDictionary *) cache {
	NSString *key = [NSString stringWithFormat:@"%d-%@", options, pattern];
	NSRegularExpression *regularExpression = cache[key];
	
	if (regularExpression)
		return regularExpression;
	
	regularExpression = [NSRegularExpression regularExpressionWithPattern:pattern options:options error:nil];
	
	cache[key] = regularExpression;
	
	return regularExpression;
}
@end
