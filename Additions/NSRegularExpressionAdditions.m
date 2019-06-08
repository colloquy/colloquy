#import "NSRegularExpressionAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSRegularExpression (Additions)
+ (NSRegularExpression *) cachedRegularExpressionWithPattern:(NSString *) pattern options:(NSRegularExpressionOptions) options error:(NSError *__autoreleasing*) error {
	static NSMutableDictionary *dangerousCache = nil;
	static dispatch_once_t pred;
	static dispatch_queue_t cacheQueue = NULL;
	dispatch_once(&pred, ^{
		dangerousCache = [[NSMutableDictionary alloc] init];
		cacheQueue = dispatch_queue_create("info.colloquy.regex.cache", DISPATCH_QUEUE_SERIAL);
	});

	__block NSRegularExpression *regularExpression = NULL;
	dispatch_sync(cacheQueue, ^{
		NSString *patternKey = dangerousCache[pattern];
		if (!patternKey) {
			@synchronized([NSRegularExpression class]) {
				patternKey = [NSRegularExpression escapedPatternForString:pattern];
				dangerousCache[pattern] = patternKey;
			}
		}

		NSString *key = [NSString stringWithFormat:@"%@-%@", @(options), patternKey];
		regularExpression = dangerousCache[key];

		if (!regularExpression) {
			NSError *internalError = nil;
			regularExpression = [NSRegularExpression regularExpressionWithPattern:pattern options:options error:&internalError];
			if (!regularExpression) {
				NSLog(@"%@", internalError);
				if (error) *error = internalError;
			} else {
				dangerousCache[key] = regularExpression;
			}
		}
	});

	return regularExpression;
}

- (NSArray <NSTextCheckingResult *> *) cq_matchesInString:(NSString *) string {
	return [self matchesInString:string options:NSMatchingReportCompletion range:NSMakeRange(0, string.length)];
}
@end

NS_ASSUME_NONNULL_END
