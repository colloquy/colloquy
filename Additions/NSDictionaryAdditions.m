#import "NSDictionaryAdditions.h"

@implementation NSDictionary (NSDictionaryAdditions)
- (id) initWithKeys:(NSArray *) keys fromDictionary:(NSDictionary *) dictionary {
	return [[NSMutableDictionary alloc] initWithKeys:keys fromDictionary:dictionary];
}

- (NSData *) postDataRepresentation {
	NSMutableData *body = [[NSMutableData alloc] init];

	NSData *equals = [@"=" dataUsingEncoding:NSUTF8StringEncoding];
	NSData *ampersand = [@"&" dataUsingEncoding:NSUTF8StringEncoding];

	[self enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
		[body appendData:[key dataUsingEncoding:NSUTF8StringEncoding]];
		[body appendData:equals];

		NSString *percentEncodedValue = [value stringByEncodingIllegalURLCharacters];
		[body appendData:[percentEncodedValue dataUsingEncoding:NSUTF8StringEncoding]];
		[body appendData:ampersand];
	}];

	if (body.length)
		return [body subdataWithRange:NSMakeRange(0, body.length - 1)];
	return [NSData data];
}
@end

@implementation NSMutableDictionary (NSDictionaryAdditions)
- (id) initWithKeys:(NSArray *) keys fromDictionary:(NSDictionary *) dictionary {
	if (!(self = [self init]))
		return nil;

	[self setObjectsForKeys:keys fromDictionary:dictionary];

	return self;
}

- (void) setObjectsForKeys:(NSArray *) keys fromDictionary:(NSDictionary *) dictionary {
	for (id key in keys) {
		id value = [dictionary objectForKey:key];
		if (value) [self setObject:value forKey:key];
	}
}
@end
