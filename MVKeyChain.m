#import <Foundation/Foundation.h>
#import "MVKeyChain.h"

#define MVStringByteLength(a) (( [a UTF8String] ? strlen( [a UTF8String] ) : 0 ))

static MVKeyChain *MVDefaultKeyChain = nil;

@implementation MVKeyChain
+ (MVKeyChain *) defaultKeyChain {
	extern MVKeyChain *MVDefaultKeyChain;
	return ( MVDefaultKeyChain ? MVDefaultKeyChain : ( MVDefaultKeyChain = [[self alloc] init] ) );
}

- (void) dealloc {
	extern MVKeyChain *MVDefaultKeyChain;
	if( MVDefaultKeyChain == self ) MVDefaultKeyChain = nil;
	[super dealloc];
}

- (void) setGenericPassword:(NSString *) password forService:(NSString *) service account:(NSString *) account {
	OSStatus ret = 0;

	NSParameterAssert( [service length] != 0 );
	NSParameterAssert( [account length] != 0 );

	if( ! [password length] ) {
		[self removeGenericPasswordForService:service account:account];
	} else if( ! [[self genericPasswordForService:service account:account] isEqualToString:password] ) {
		[self removeGenericPasswordForService:service account:account];
		ret = SecKeychainAddGenericPassword( NULL, MVStringByteLength( service ), [service UTF8String], MVStringByteLength( account ), [account UTF8String], MVStringByteLength( password ), (void *) [password UTF8String], NULL );
	}
}

- (NSString *) genericPasswordForService:(NSString *) service account:(NSString *) account {
	OSStatus ret = 0;
	unsigned long len = 0;
	void *p = NULL;
	NSString *string = nil;

	ret = SecKeychainFindGenericPassword( NULL, MVStringByteLength( service ), [service UTF8String], MVStringByteLength( account ), [account UTF8String], &len, &p, NULL );
	if( ! ret ) string = [NSString stringWithUTF8String:(const char *) p];

	return string;
}

- (void) removeGenericPasswordForService:(NSString *) service account:(NSString *) account {
	OSStatus ret = 0;
	SecKeychainItemRef itemref = NULL;

	NSParameterAssert( [service length] != 0 );
	NSParameterAssert( [account length] != 0 );

	ret = SecKeychainFindGenericPassword( NULL, MVStringByteLength( service ), [service UTF8String], MVStringByteLength( account ), [account UTF8String], NULL, NULL, &itemref );
	SecKeychainItemDelete( itemref );
}

- (void) setInternetPassword:(NSString *) password forServer:(NSString *) server securityDomain:(NSString *) domain account:(NSString *) account path:(NSString *) path port:(unsigned short) port protocol:(MVKeyChainProtocol) protocol authenticationType:(MVKeyChainAuthenticationType) authType {
	OSStatus ret = 0;

	NSParameterAssert( [server length] != 0 );
	NSParameterAssert( [account length] != 0 );

	if( ! [password length] ) {
		[self removeInternetPasswordForServer:server securityDomain:domain account:account path:nil port:port protocol:protocol authenticationType:authType];
	} else if( ! [[self internetPasswordForServer:server securityDomain:domain account:account path:nil port:port protocol:protocol authenticationType:authType] isEqualToString:password] ) {
		[self removeInternetPasswordForServer:server securityDomain:domain account:account path:nil port:port protocol:protocol authenticationType:authType];
		ret = SecKeychainAddInternetPassword( NULL, MVStringByteLength( server ), [server UTF8String], MVStringByteLength( domain ), [domain UTF8String], MVStringByteLength( account ), [account UTF8String], MVStringByteLength( path ), [path UTF8String], port, protocol, authType, MVStringByteLength( password ), (void *) [password UTF8String], NULL );
	}
}

- (NSString *) internetPasswordForServer:(NSString *) server securityDomain:(NSString *) domain account:(NSString *) account path:(NSString *) path port:(unsigned short) port protocol:(MVKeyChainProtocol) protocol authenticationType:(MVKeyChainAuthenticationType) authType {
	OSStatus ret = 0;
	unsigned long len = 0;
	void *p = NULL;
	NSString *string = nil;

	ret = SecKeychainFindInternetPassword( NULL, MVStringByteLength( server ), [server UTF8String], MVStringByteLength( domain ), [domain UTF8String], MVStringByteLength( account ), [account UTF8String], MVStringByteLength( path ), [path UTF8String], port, protocol, authType, &len, &p, NULL );
	if( ! ret ) string = [NSString stringWithUTF8String:(const char *) p];

	return string;
}

- (void) removeInternetPasswordForServer:(NSString *) server securityDomain:(NSString *) domain account:(NSString *) account path:(NSString *) path port:(unsigned short) port protocol:(MVKeyChainProtocol) protocol authenticationType:(MVKeyChainAuthenticationType) authType {
	OSStatus ret = 0;
	SecKeychainItemRef itemref = NULL;

	NSParameterAssert( [server length] != 0 );
	NSParameterAssert( [account length] != 0 );

	ret = SecKeychainFindInternetPassword( NULL, MVStringByteLength( server ), [server UTF8String], MVStringByteLength( domain ), [domain UTF8String], MVStringByteLength( account ), [account UTF8String], MVStringByteLength( path ), [path UTF8String], port, protocol, authType, NULL, NULL, &itemref );
	SecKeychainItemDelete( itemref );
}
@end