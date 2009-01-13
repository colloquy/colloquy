#import "CQKeychain.h"

#import <Security/Security.h>

static inline size_t stringByteLength(NSString *string) {
	const char * const utf8String = [string UTF8String];
	return (utf8String ? strlen(utf8String) : 0);
}

@implementation CQKeychain
+ (CQKeychain *) standardKeychain {
	static CQKeychain *sharedInstance;
	if (!sharedInstance) sharedInstance = [[self alloc] init];
	return sharedInstance;
}

#if !TARGET_IPHONE_SIMULATOR
static NSMutableDictionary *createBaseDictionary(NSString *server, NSString *account) {
	NSCParameterAssert(server);

	NSMutableDictionary *query = [[NSMutableDictionary alloc] init];

	[query setObject:(id)kSecClassInternetPassword forKey:(id)kSecClass];
	[query setObject:server forKey:(id)kSecAttrServer];
	if (account) [query setObject:account forKey:(id)kSecAttrAccount];

	return query;
}
#endif

- (void) setPassword:(NSString *) password forServer:(NSString *) server account:(NSString *) account {
	NSParameterAssert(server);

#if !TARGET_IPHONE_SIMULATOR
	if (!password.length) {
		[self removePasswordForServer:server account:account];
		return;
	}

	NSMutableDictionary *passwordEntry = createBaseDictionary(server, account);
	NSMutableDictionary *attributesToUpdate = [[NSMutableDictionary alloc] init];

	NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
	[attributesToUpdate setObject:passwordData forKey:(id)kSecValueData];

	OSStatus status = SecItemUpdate((CFDictionaryRef)passwordEntry, (CFDictionaryRef)attributesToUpdate);

	[attributesToUpdate release];

	if (status == noErr) {
		[passwordEntry release];
		return;
	}

	SecItemDelete((CFDictionaryRef)passwordEntry);

	[passwordEntry setObject:passwordData forKey:(id)kSecValueData];

	SecItemAdd((CFDictionaryRef)passwordEntry, NULL);

	[passwordEntry release];
#else
	[self removePasswordForServer:server account:account];

	if (password.length)
		SecKeychainAddInternetPassword(NULL, stringByteLength(server), [server UTF8String], 0, NULL, stringByteLength(account), [account UTF8String], 0, NULL, 0, 0, 0, stringByteLength(password), (void *) [password UTF8String], NULL);
#endif
}

- (NSString *) passwordForServer:(NSString *) server account:(NSString *) account {
	NSParameterAssert(server);

	NSString *string = nil;

#if !TARGET_IPHONE_SIMULATOR
	NSMutableDictionary *passwordQuery = createBaseDictionary(server, account);
	NSData *resultData = nil;

	[passwordQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
	[passwordQuery setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];

	OSStatus status = SecItemCopyMatching((CFDictionaryRef)passwordQuery, (CFTypeRef *)&resultData);
	if (status == noErr && resultData)
		string = [[NSString alloc] initWithData:resultData encoding:NSUTF8StringEncoding];

	[passwordQuery release];
#else
	unsigned long passwordLength = 0;
	void *password = NULL;

	OSStatus status = SecKeychainFindInternetPassword(NULL, stringByteLength(server), [server UTF8String], 0, NULL, stringByteLength(account), [account UTF8String], 0, NULL, 0, 0, 0, &passwordLength, &password, NULL);
	if (status == noErr)
		string = [[NSString allocWithZone:nil] initWithBytes:(const void *)password length:passwordLength encoding:NSUTF8StringEncoding];
	SecKeychainItemFreeContent(NULL, password);
#endif

	return [string autorelease];
}

- (void) removePasswordForServer:(NSString *) server account:(NSString *) account {
	NSParameterAssert(server);

#if !TARGET_IPHONE_SIMULATOR
	NSMutableDictionary *passwordQuery = createBaseDictionary(server, account);
	SecItemDelete((CFDictionaryRef)passwordQuery);
	[passwordQuery release];
#else
	SecKeychainItemRef keychainItem = NULL;
	OSStatus status = SecKeychainFindInternetPassword(NULL, stringByteLength(server), [server UTF8String], 0, NULL, stringByteLength(account), [account UTF8String], 0, NULL, 0, 0, 0, NULL, NULL, &keychainItem);
	if (status == noErr)
		SecKeychainItemDelete(keychainItem);
#endif
}
@end
