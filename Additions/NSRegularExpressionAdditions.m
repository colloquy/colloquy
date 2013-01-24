#import "NSRegularExpressionAdditions.h"

@implementation NSRegularExpression (Additions)
+ (id) threadsafeCachedObjectForKey:(id) key {
	return [NSThread currentThread].threadDictionary[key];
}

+ (void) cacheObject:(id) object inThreadsafeDictionaryWithKey:(id) key {
	[NSThread currentThread].threadDictionary[key] = object;
}

+ (NSRegularExpression *) cachedRegularExpressionWithPattern:(NSString *) pattern options:(NSRegularExpressionOptions) options error:(NSError *__autoreleasing*) error {
	NSNumber *optionsNumber = [NSNumber numberWithInteger:options];
	NSMutableDictionary *optionsDictionary = [self threadsafeCachedObjectForKey:optionsNumber];
	NSRegularExpression *regularExpression;
	
	if (!optionsDictionary)
		goto makeOptionsDictionary;
	
	regularExpression = [self threadsafeCachedObjectForKey:optionsNumber];
	
	if (regularExpression)
		return regularExpression;
	
	goto makeRegularExpression;
	
makeOptionsDictionary:
	optionsDictionary = [NSMutableDictionary dictionary];
	
	[self cacheObject:optionsDictionary inThreadsafeDictionaryWithKey:optionsNumber];
	
makeRegularExpression:
	regularExpression = [NSRegularExpression regularExpressionWithPattern:pattern options:options error:nil];
	
	[optionsDictionary setObject:regularExpression forKey:pattern];
	
	return regularExpression;
}
@end
