#import "CQKeychain.h"

#import <Security/Security.h>

@implementation CQKeychain
+ (CQKeychain *) standardKeychain {
	static CQKeychain *sharedInstance;
	if (!sharedInstance) sharedInstance = [[self alloc] init];
	return sharedInstance;
}

static NSMutableDictionary *createBaseDictionary(NSString *server, NSString *account) {
	NSCParameterAssert(server);

	NSMutableDictionary *query = [[NSMutableDictionary alloc] init];

	query[(__bridge id)kSecClass] = (__bridge id)kSecClassInternetPassword;
	query[(__bridge id)kSecAttrServer] = server;
	if (account) query[(__bridge id)kSecAttrAccount] = account;

	return query;
}

- (void) setPassword:(NSString *) password forServer:(NSString *) server area:(NSString *) area {
	NSParameterAssert(server);

	if (!password.length) {
		[self removePasswordForServer:server area:area];
		return;
	}

	NSMutableDictionary *passwordEntry = createBaseDictionary(server, area);

	NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
	passwordEntry[(__bridge id)kSecValueData] = passwordData;

	OSStatus status = SecItemAdd((__bridge CFDictionaryRef)passwordEntry, NULL);
	if (status == errSecDuplicateItem) {
		[passwordEntry removeObjectForKey:(__bridge id)kSecValueData];

		NSMutableDictionary *attributesToUpdate = [[NSMutableDictionary alloc] initWithObjectsAndKeys:passwordData, (__bridge id)kSecValueData, nil];

		SecItemUpdate((__bridge CFDictionaryRef)passwordEntry, (__bridge CFDictionaryRef)attributesToUpdate);
	}
}

- (NSString *) passwordForServer:(NSString *) server area:(NSString *) area {
	NSParameterAssert(server);

	NSString *string = nil;

	NSMutableDictionary *passwordQuery = createBaseDictionary(server, area);

	passwordQuery[(__bridge id)kSecReturnData] = (id)kCFBooleanTrue;
	passwordQuery[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;

	CFTypeRef resultDataRef;
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)passwordQuery, &resultDataRef);
	if (status == noErr && resultDataRef) {
		string = [[NSString alloc] initWithData:(__bridge NSData *)resultDataRef encoding:NSUTF8StringEncoding];
		CFRelease(resultDataRef);
	}

	return string;
}

- (void) removePasswordForServer:(NSString *) server area:(NSString *) area {
	NSParameterAssert(server);

	NSMutableDictionary *passwordQuery = createBaseDictionary(server, area);
	SecItemDelete((__bridge CFDictionaryRef)passwordQuery);
}
@end
