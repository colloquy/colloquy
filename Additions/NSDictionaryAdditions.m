#import "NSDictionaryAdditions.h"

@implementation NSDictionary (NSDictionaryAdditions)
+ (id) dictionaryWithKeys:(id *) keys fromDictionary:(NSDictionary *) dictionary {
	return [[[[self class] alloc] initWithKeys:keys fromDictionary:dictionary] autorelease];
}

- (id) initWithKeys:(id *) keys fromDictionary:(NSDictionary *) dictionary {
	NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithKeys:keys fromDictionary:dictionary];

	self = [self initWithDictionary:result];

	[result release];

	return self;
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
