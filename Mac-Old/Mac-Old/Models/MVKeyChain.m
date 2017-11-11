#import "MVKeyChain.h"

#define MVStringByteLength(a) (( [a UTF8String] ? (UInt32)strlen( [a UTF8String] ) : 0 ))

static MVKeyChain *sharedInstance = nil;

@implementation MVKeyChain
+ (MVKeyChain *) defaultKeyChain {
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] init] ) );
}

- (NSString *) genericPasswordForService:(NSString *) service account:(NSString *) account {
	OSStatus ret = 0;
	UInt32 len = 0;
	void *p = NULL;
	NSString *string = nil;

	ret = SecKeychainFindGenericPassword( NULL, MVStringByteLength( service ), [service UTF8String], MVStringByteLength( account ), [account UTF8String], &len, &p, NULL );
	if( ret == noErr ) {
		if ( p )
			string = [[NSString alloc] initWithBytes:(const void *) p length:len encoding:NSUTF8StringEncoding];
	}
	if( p ) {
		SecKeychainItemFreeContent( NULL, p );
	}

	return string;
}

- (void) removeGenericPasswordForService:(NSString *) service account:(NSString *) account {
	OSStatus ret = 0;
	SecKeychainItemRef itemref = NULL;

	NSParameterAssert( service );
	NSParameterAssert( account );

	ret = SecKeychainFindGenericPassword( NULL, MVStringByteLength( service ), [service UTF8String], MVStringByteLength( account ), [account UTF8String], NULL, NULL, &itemref );
	if( ret == noErr ) SecKeychainItemDelete( itemref );
}

- (NSString *) internetPasswordForServer:(NSString *) server securityDomain:(NSString *) domain account:(NSString *) account path:(NSString *) path port:(unsigned short) port protocol:(MVKeyChainProtocol) protocol authenticationType:(MVKeyChainAuthenticationType) authType {
	OSStatus ret = 0;
	UInt32 len = 0;
	void *p = NULL;
	NSString *string = nil;

	ret = SecKeychainFindInternetPassword( NULL, MVStringByteLength( server ), [server UTF8String], MVStringByteLength( domain ), [domain UTF8String], MVStringByteLength( account ), [account UTF8String], MVStringByteLength( path ), [path UTF8String], port, protocol, authType, &len, &p, NULL );
	if( ret == noErr ) {
		if ( p ) {
			string = [[NSString alloc] initWithBytes:(const void *) p length:len encoding:NSUTF8StringEncoding];
		}
	}
	if ( p ) {
		SecKeychainItemFreeContent( NULL, p );
	}

	return string;
}

- (void) removeInternetPasswordForServer:(NSString *) server securityDomain:(NSString *) domain account:(NSString *) account path:(NSString *) path port:(unsigned short) port protocol:(MVKeyChainProtocol) protocol authenticationType:(MVKeyChainAuthenticationType) authType {
	OSStatus ret = 0;
	SecKeychainItemRef itemref = NULL;

	NSParameterAssert( server || account );

	ret = SecKeychainFindInternetPassword( NULL, MVStringByteLength( server ), [server UTF8String], MVStringByteLength( domain ), [domain UTF8String], MVStringByteLength( account ), [account UTF8String], MVStringByteLength( path ), [path UTF8String], port, protocol, authType, NULL, NULL, &itemref );
	if( ret == noErr ) SecKeychainItemDelete( itemref );
}
@end
