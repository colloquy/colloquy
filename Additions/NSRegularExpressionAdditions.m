#import "NSRegularExpressionAdditions.h"

@implementation NSRegularExpression (Additions)
static NSMutableDictionary *regularExpressions = nil;

+ (void) load {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		regularExpressions = [[NSMutableDictionary alloc] init];
	});
}

+ (NSRegularExpression *) cachedRegularExpressionWithPattern:(NSString *) pattern options:(NSRegularExpressionOptions) options error:(NSError *__autoreleasing*) error {
	NSNumber *optionsNumber = [NSNumber numberWithInteger:options];
	NSMutableDictionary *optionsDictionary = [regularExpressions objectForKey:optionsNumber];
	NSRegularExpression *regularExpression;
	
	if (!optionsDictionary)
		goto makeOptionsDictionary;
	
	regularExpression = [optionsDictionary objectForKey:pattern];
	
	if (regularExpression)
		return regularExpression;
	
	goto makeRegularExpression;
	
makeOptionsDictionary:
	optionsDictionary = [NSMutableDictionary dictionary];
	
	[regularExpressions setObject:optionsDictionary forKey:optionsNumber];
	
makeRegularExpression:
	regularExpression = [NSRegularExpression regularExpressionWithPattern:pattern options:options error:nil];
	
	[optionsDictionary setObject:regularExpression forKey:pattern];
	
	return regularExpression;
}
@end
