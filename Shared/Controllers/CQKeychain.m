#import "CQKeychain.h"

#import <Security/Security.h>

NS_ASSUME_NONNULL_BEGIN

@implementation CQKeychain
+ (CQKeychain *) standardKeychain {
	static CQKeychain *sharedInstance;
	if (!sharedInstance) sharedInstance = [[self alloc] init];
	return sharedInstance;
}

static NSMutableDictionary *createBaseDictionary(NSString *server, NSString *__nullable account) {
	NSCParameterAssert(server);

	NSMutableDictionary *query = [[NSMutableDictionary alloc] init];

	query[(__bridge id)kSecClass] = (__bridge id)kSecClassInternetPassword;
	query[(__bridge id)kSecAttrServer] = server;
	if (account) query[(__bridge id)kSecAttrAccount] = account;

	return query;
}

- (void) setPassword:(NSString *) password forServer:(NSString *) server area:(NSString *__nullable) area {
	[self setPassword:password forServer:server area:area displayValue:nil];
}

- (void) setPassword:(NSString *) password forServer:(NSString *) server area:(NSString *__nullable) area displayValue:(NSString *__nullable)displayValue {
	if (!password.length) {
		[self removePasswordForServer:server area:area];
		return;
	}

	NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];

	[self setData:passwordData forServer:server area:area];
}

- (void) setData:(NSData *) passwordData forServer:(NSString *) server area:(NSString *__nullable) area {
	[self setData:passwordData forServer:server area:area displayValue:nil];
}

- (void) setData:(NSData *) passwordData forServer:(NSString *) server area:(NSString *__nullable) area displayValue:(NSString *__nullable)displayValue {
	NSParameterAssert(server);

	if (!passwordData.length) {
		[self removeDataForServer:server area:area];
		return;
	}

	NSMutableDictionary *passwordEntry = createBaseDictionary(server, area);

	passwordEntry[(__bridge id)kSecValueData] = passwordData;
	if (displayValue) passwordEntry[(__bridge id)kSecAttrLabel] = displayValue;

	OSStatus status = SecItemAdd((__bridge CFDictionaryRef)passwordEntry, NULL);
	if (status == errSecDuplicateItem) {
		[passwordEntry removeObjectForKey:(__bridge id)kSecValueData];

		NSMutableDictionary *attributesToUpdate = [[NSMutableDictionary alloc] initWithObjectsAndKeys:passwordData, (__bridge id)kSecValueData, nil];

		SecItemUpdate((__bridge CFDictionaryRef)passwordEntry, (__bridge CFDictionaryRef)attributesToUpdate);
	}
}

- (NSString *__nullable) passwordForServer:(NSString *) server area:(NSString *__nullable) area {
	NSData *data = [self dataForServer:server area:area];
	return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (NSData *__nullable) dataForServer:(NSString *) server area:(NSString *__nullable) area {
	NSParameterAssert(server);

	NSMutableDictionary *passwordQuery = createBaseDictionary(server, area);

	passwordQuery[(__bridge id)kSecReturnData] = @YES;
	passwordQuery[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;

	CFTypeRef resultDataRef;
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)passwordQuery, &resultDataRef);
	if (status == noErr && resultDataRef)
		return CFBridgingRelease(resultDataRef);

	return nil;
}

- (void) removePasswordForServer:(NSString *) server area:(NSString *__nullable) area {
	[self removeDataForServer:server area:area];
}

- (void) removeDataForServer:(NSString *) server area:(NSString *__nullable) area {
	NSParameterAssert(server);

	NSMutableDictionary *passwordQuery = createBaseDictionary(server, area);
	SecItemDelete((__bridge CFDictionaryRef)passwordQuery);
}
@end

NS_ASSUME_NONNULL_END
