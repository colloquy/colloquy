#import "NSDictionaryAdditions.h"

@implementation NSDictionary (NSDictionaryAdditions)
- (id) initWithKeys:(NSArray *) keys fromDictionary:(NSDictionary *) dictionary {
	return [[NSMutableDictionary alloc] initWithKeys:keys fromDictionary:dictionary];
}
@end

@implementation NSMutableDictionary (NSDictionaryAdditions)
- (id) initWithKeys:(NSArray *) keys fromDictionary:(NSDictionary *) dictionary {
	if (!(self = [self init]))
		return nil;

	for (id key in keys) {
		id value = [dictionary objectForKey:key];
		if (value) [self setObject:value forKey:key];
	}

	return self;
}
@end
