#import "NSRegularExpressionAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSRegularExpression (Additions)
+ (nullable NSRegularExpression *) cachedRegularExpressionWithPattern:(NSString *) pattern options:(NSRegularExpressionOptions) options error:(NSError *__autoreleasing*) error {
	static NSMutableDictionary *dangerousCache = nil;
	static dispatch_once_t pred;
	dispatch_once(&pred, ^{
		dangerousCache = [[NSMutableDictionary alloc] init];
	});

	NSString *patternKey = dangerousCache[pattern];
	if (!patternKey) {
		patternKey = [NSRegularExpression escapedPatternForString:pattern];
		dangerousCache[pattern] = patternKey;
	}
#if SYSTEM(MAC)
	NSString *key = [[NSString alloc] initWithFormat:@"%ld-%@", options, patternKey];
#else
	NSString *key = [[NSString alloc] initWithFormat:@"%tu-%@", options, patternKey];
#endif
	NSRegularExpression *regularExpression = dangerousCache[key];

	if (regularExpression)
		return regularExpression;

	NSError *internalError = nil;
	regularExpression = [NSRegularExpression regularExpressionWithPattern:pattern options:options error:&internalError];
	if (!regularExpression) {
		NSLog(@"%@", internalError);
		if (error) *error = internalError;
	} else {
		dangerousCache[key] = regularExpression;
	}

	return regularExpression;
}

- (NSArray <NSTextCheckingResult *> *) cq_matchesInString:(NSString *) string {
	return [self matchesInString:string options:NSMatchingReportCompletion range:NSMakeRange(0, string.length)];
}
@end

NS_ASSUME_NONNULL_END
