#import "MVKeyChain.h"

#define MVStringByteLength(a) (( [a UTF8String] ? strlen( [a UTF8String] ) : 0 ))

static MVKeyChain *sharedInstance = nil;

@implementation MVKeyChain
+ (MVKeyChain *) defaultKeyChain {
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] init] ) );
}

- (void) dealloc {
	if( sharedInstance == self ) sharedInstance = nil;
	[super dealloc];
}

- (void) setGenericPassword:(NSString *) password forService:(NSString *) service account:(NSString *) account {
	NSParameterAssert( service );
	NSParameterAssert( account );

	if( ! [password length] ) {
		[self removeGenericPasswordForService:service account:account];
	} else if( ! [[self genericPasswordForService:service account:account] isEqualToString:password] ) {
		[self removeGenericPasswordForService:service account:account];
		SecKeychainAddGenericPassword( NULL, MVStringByteLength( service ), [service UTF8String], MVStringByteLength( account ), [account UTF8String], MVStringByteLength( password ), (void *) [password UTF8String], NULL );
	}
}

- (NSString *) genericPasswordForService:(NSString *) service account:(NSString *) account {
	OSStatus ret = 0;
	unsigned long len = 0;
	void *p = NULL;
	NSString *string = nil;

	ret = SecKeychainFindGenericPassword( NULL, MVStringByteLength( service ), [service UTF8String], MVStringByteLength( account ), [account UTF8String], &len, &p, NULL );
	if( ret == noErr ) string = [[NSString allocWithZone:nil] initWithBytes:(const void *) p length:len encoding:NSUTF8StringEncoding];
	SecKeychainItemFreeContent( NULL, p );

	return [string autorelease];
}

- (void) removeGenericPasswordForService:(NSString *) service account:(NSString *) account {
	OSStatus ret = 0;
	SecKeychainItemRef itemref = NULL;

	NSParameterAssert( service );
	NSParameterAssert( account );

	ret = SecKeychainFindGenericPassword( NULL, MVStringByteLength( service ), [service UTF8String], MVStringByteLength( account ), [account UTF8String], NULL, NULL, &itemref );
	if( ret == noErr ) SecKeychainItemDelete( itemref );
}

- (void) setInternetPassword:(NSString *) password forServer:(NSString *) server securityDomain:(NSString *) domain account:(NSString *) account path:(NSString *) path port:(unsigned short) port protocol:(MVKeyChainProtocol) protocol authenticationType:(MVKeyChainAuthenticationType) authType {
	NSParameterAssert( server || account );

	if( ! [password length] ) {
		[self removeInternetPasswordForServer:server securityDomain:domain account:account path:nil port:port protocol:protocol authenticationType:authType];
	} else if( ! [[self internetPasswordForServer:server securityDomain:domain account:account path:nil port:port protocol:protocol authenticationType:authType] isEqualToString:password] ) {
		[self removeInternetPasswordForServer:server securityDomain:domain account:account path:nil port:port protocol:protocol authenticationType:authType];
		SecKeychainAddInternetPassword( NULL, MVStringByteLength( server ), [server UTF8String], MVStringByteLength( domain ), [domain UTF8String], MVStringByteLength( account ), [account UTF8String], MVStringByteLength( path ), [path UTF8String], port, protocol, authType, MVStringByteLength( password ), (void *) [password UTF8String], NULL );
	}
}

- (NSString *) internetPasswordForServer:(NSString *) server securityDomain:(NSString *) domain account:(NSString *) account path:(NSString *) path port:(unsigned short) port protocol:(MVKeyChainProtocol) protocol authenticationType:(MVKeyChainAuthenticationType) authType {
	OSStatus ret = 0;
	unsigned long len = 0;
	void *p = NULL;
	NSString *string = nil;

	ret = SecKeychainFindInternetPassword( NULL, MVStringByteLength( server ), [server UTF8String], MVStringByteLength( domain ), [domain UTF8String], MVStringByteLength( account ), [account UTF8String], MVStringByteLength( path ), [path UTF8String], port, protocol, authType, &len, &p, NULL );
	if( ret == noErr ) string = [[NSString allocWithZone:nil] initWithBytes:(const void *) p length:len encoding:NSUTF8StringEncoding];
	SecKeychainItemFreeContent( NULL, p );

	return [string autorelease];
}

- (void) removeInternetPasswordForServer:(NSString *) server securityDomain:(NSString *) domain account:(NSString *) account path:(NSString *) path port:(unsigned short) port protocol:(MVKeyChainProtocol) protocol authenticationType:(MVKeyChainAuthenticationType) authType {
	OSStatus ret = 0;
	SecKeychainItemRef itemref = NULL;

	NSParameterAssert( server || account );

	ret = SecKeychainFindInternetPassword( NULL, MVStringByteLength( server ), [server UTF8String], MVStringByteLength( domain ), [domain UTF8String], MVStringByteLength( account ), [account UTF8String], MVStringByteLength( path ), [path UTF8String], port, protocol, authType, NULL, NULL, &itemref );
	if( ret == noErr ) SecKeychainItemDelete( itemref );
}
@end