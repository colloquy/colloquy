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

static NSMutableDictionary *createBaseDictionary(NSString *server, NSString *account) {
	NSCParameterAssert(server);

	NSMutableDictionary *query = [[NSMutableDictionary alloc] init];

	query[(id)kSecClass] = (id)kSecClassInternetPassword;
	query[(id)kSecAttrServer] = server;
	if (account) query[(id)kSecAttrAccount] = account;

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
	passwordEntry[(id)kSecValueData] = passwordData;

	OSStatus status = SecItemAdd((CFDictionaryRef)passwordEntry, NULL);
	if (status == errSecDuplicateItem) {
		[passwordEntry removeObjectForKey:(id)kSecValueData];

		NSMutableDictionary *attributesToUpdate = [[NSMutableDictionary alloc] initWithObjectsAndKeys:passwordData, (id)kSecValueData, nil];

		SecItemUpdate((CFDictionaryRef)passwordEntry, (CFDictionaryRef)attributesToUpdate);

		[attributesToUpdate release];
	}

	[passwordEntry release];
}

- (NSString *) passwordForServer:(NSString *) server area:(NSString *) area {
	NSParameterAssert(server);

	NSString *string = nil;

	NSMutableDictionary *passwordQuery = createBaseDictionary(server, area);
	NSData *resultData = nil;

	passwordQuery[(id)kSecReturnData] = (id)kCFBooleanTrue;
	passwordQuery[(id)kSecMatchLimit] = (id)kSecMatchLimitOne;

	OSStatus status = SecItemCopyMatching((CFDictionaryRef)passwordQuery, (CFTypeRef *)&resultData);
	if (status == noErr && resultData) {
		string = [[NSString alloc] initWithData:resultData encoding:NSUTF8StringEncoding];
		[resultData release];
	}

	[passwordQuery release];

	return [string autorelease];
}

- (void) removePasswordForServer:(NSString *) server area:(NSString *) area {
	NSParameterAssert(server);

	NSMutableDictionary *passwordQuery = createBaseDictionary(server, area);
	SecItemDelete((CFDictionaryRef)passwordQuery);
	[passwordQuery release];
}
@end
