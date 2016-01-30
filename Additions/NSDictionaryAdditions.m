#import "NSDictionaryAdditions.h"
#import "NSStringAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSDictionary (NSDictionaryAdditions)
+ (NSDictionary *) dictionaryWithKeys:(NSArray <id <NSCopying>> *) keys fromDictionary:(NSDictionary *) dictionary {
	return [[NSMutableDictionary alloc] initWithKeys:keys fromDictionary:dictionary];
}

- (NSData *) postDataRepresentation {
	NSMutableData *body = [[NSMutableData alloc] init];

	NSData *equals = [@"=" dataUsingEncoding:NSUTF8StringEncoding];
	NSData *ampersand = [@"&" dataUsingEncoding:NSUTF8StringEncoding];

	[self enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
		NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
		if (!keyData) return;

		[body appendData:keyData];
		[body appendData:equals];

		NSString *percentEncodedValue = [value stringByEncodingIllegalURLCharacters];
		NSData *percentEncodedValueData = [percentEncodedValue dataUsingEncoding:NSUTF8StringEncoding];
		if (!percentEncodedValueData) return;

		[body appendData:percentEncodedValueData];
		[body appendData:ampersand];
	}];

	if (body.length)
		return [body subdataWithRange:NSMakeRange(0, body.length - 1)];
	return [NSData data];
}
@end

@implementation NSMutableDictionary (NSDictionaryAdditions)
- (instancetype) initWithKeys:(NSArray <id <NSCopying>> *) keys fromDictionary:(NSDictionary *) dictionary {
	if (!(self = [self init]))
		return nil;

	[self setObjectsForKeys:keys fromDictionary:dictionary];

	return self;
}

- (void) setObjectsForKeys:(NSArray <id <NSCopying>> *) keys fromDictionary:(NSDictionary *) dictionary {
	for (id key in keys) {
		id value = dictionary[key];
		if (value) self[key] = value;
	}
}
@end

NS_ASSUME_NONNULL_END
