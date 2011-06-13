#import "CQKeychain.h"

#import <Security/Security.h>

MVInline size_t stringByteLength(NSString *string) {
	const char * const utf8String = [string UTF8String];
	return (utf8String ? strlen(utf8String) : 0);
}

@implementation CQKeychain
+ (CQKeychain *) standardKeychain {
	static CQKeychain *sharedInstance;
	if (!sharedInstance) sharedInstance = [[self alloc] init];
	return sharedInstance;
}

#if SYSTEM(IOS) && !SYSTEM(IOS_SIMULATOR)
static NSMutableDictionary *createBaseDictionary(NSString *server, NSString *account) {
	NSCParameterAssert(server);

	NSMutableDictionary *query = [[NSMutableDictionary alloc] init];

	[query setObject:(id)kSecClassInternetPassword forKey:(id)kSecClass];
	[query setObject:server forKey:(id)kSecAttrServer];
	if (account) [query setObject:account forKey:(id)kSecAttrAccount];

	return query;
}
#endif

- (void) setPassword:(NSString *) password forServer:(NSString *) server area:(NSString *) area {
	NSParameterAssert(server);

#if SYSTEM(IOS) && !SYSTEM(IOS_SIMULATOR)
	if (!password.length) {
		[self removePasswordForServer:server area:area];
		return;
	}

	NSMutableDictionary *passwordEntry = createBaseDictionary(server, area);

	NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
	[passwordEntry setObject:passwordData forKey:(id)kSecValueData];

	OSStatus status = SecItemAdd((CFDictionaryRef)passwordEntry, NULL);
	if (status == errSecDuplicateItem) {
		[passwordEntry removeObjectForKey:(id)kSecValueData];

		NSMutableDictionary *attributesToUpdate = [[NSMutableDictionary alloc] initWithObjectsAndKeys:passwordData, (id)kSecValueData, nil];

		SecItemUpdate((CFDictionaryRef)passwordEntry, (CFDictionaryRef)attributesToUpdate);

		[attributesToUpdate release];
	}

	[passwordEntry release];
#else
	[self removePasswordForServer:server area:area];

	if (password.length)
		SecKeychainAddInternetPassword(NULL, stringByteLength(server), [server UTF8String], 0, NULL, stringByteLength(area), [area UTF8String], 0, NULL, 0, 0, 0, stringByteLength(password), (void *) [password UTF8String], NULL);
#endif
}

- (NSString *) passwordForServer:(NSString *) server area:(NSString *) area {
	NSParameterAssert(server);

	NSString *string = nil;

#if SYSTEM(IOS) && !SYSTEM(IOS_SIMULATOR)
	NSMutableDictionary *passwordQuery = createBaseDictionary(server, area);
	NSData *resultData = nil;

	[passwordQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
	[passwordQuery setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];

	OSStatus status = SecItemCopyMatching((CFDictionaryRef)passwordQuery, (CFTypeRef *)&resultData);
	if (status == noErr && resultData) {
		string = [[NSString alloc] initWithData:resultData encoding:NSUTF8StringEncoding];
		[resultData release];
	}

	[passwordQuery release];
#else
	UInt32 passwordLength = 0;
	void *password = NULL;

	OSStatus status = SecKeychainFindInternetPassword(NULL, stringByteLength(server), [server UTF8String], 0, NULL, stringByteLength(area), [area UTF8String], 0, NULL, 0, 0, 0, &passwordLength, &password, NULL);
	if (status == noErr)
		string = [[NSString alloc] initWithBytes:(const void *)password length:passwordLength encoding:NSUTF8StringEncoding];
	SecKeychainItemFreeContent(NULL, password);
#endif

	return [string autorelease];
}

- (void) removePasswordForServer:(NSString *) server area:(NSString *) area {
	NSParameterAssert(server);

#if SYSTEM(IOS) && !SYSTEM(IOS_SIMULATOR)
	NSMutableDictionary *passwordQuery = createBaseDictionary(server, area);
	SecItemDelete((CFDictionaryRef)passwordQuery);
	[passwordQuery release];
#else
	SecKeychainItemRef keychainItem = NULL;
	OSStatus status = SecKeychainFindInternetPassword(NULL, stringByteLength(server), [server UTF8String], 0, NULL, stringByteLength(area), [area UTF8String], 0, NULL, 0, 0, 0, NULL, NULL, &keychainItem);
	if (status == noErr)
		SecKeychainItemDelete(keychainItem);
#endif
}
@end
