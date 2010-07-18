#import "NSDictionaryAdditions.h"

@implementation NSDictionary (NSDictionaryAdditions)
- (id) initWithKeys:(id *) keys fromDictionary:(NSDictionary *) dictionary {
	return [[NSMutableDictionary alloc] initWithKeys:keys fromDictionary:dictionary];
}
@end

@implementation NSMutableDictionary (NSDictionaryAdditions)
- (id) initWithKeys:(id *) keys fromDictionary:(NSDictionary *) dictionary {
	if (!(self = [self init]))
		return nil;

	while (keys && *keys) {
		id value = [dictionary objectForKey:*keys];
		if (value) [self setObject:value forKey:*keys];
		++keys;
	}

	return self;
}
@end
