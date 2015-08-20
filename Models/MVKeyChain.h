#import <Security/Security.h>

typedef NS_ENUM(FourCharCode, MVKeyChainAuthenticationType) {
	MVKeyChainAuthenticationTypeAny = 0,
	MVKeyChainAuthenticationTypeNTLM = kSecAuthenticationTypeNTLM,
	MVKeyChainAuthenticationTypeMSN = kSecAuthenticationTypeMSN,
	MVKeyChainAuthenticationTypeDPA = kSecAuthenticationTypeDPA,
	MVKeyChainAuthenticationTypeRPA = kSecAuthenticationTypeRPA,
	MVKeyChainAuthenticationTypeHTTPDigest = kSecAuthenticationTypeHTTPDigest,
	MVKeyChainAuthenticationTypeDefault = kSecAuthenticationTypeDefault
};

typedef NS_ENUM(FourCharCode, MVKeyChainProtocol) {
	MVKeyChainProtocolAny = 0,
	MVKeyChainProtocolFTP = kSecProtocolTypeFTP,
	MVKeyChainProtocolFTPAccount = kSecProtocolTypeFTPAccount,
	MVKeyChainProtocolHTTP = kSecProtocolTypeHTTP,
	MVKeyChainProtocolIRC = kSecProtocolTypeIRC,
	MVKeyChainProtocolNNTP = kSecProtocolTypeNNTP,
	MVKeyChainProtocolPOP3 = kSecProtocolTypePOP3,
	MVKeyChainProtocolSMTP = kSecProtocolTypeSMTP,
	MVKeyChainProtocolSOCKS = kSecProtocolTypeSOCKS,
	MVKeyChainProtocolIMAP = kSecProtocolTypeIMAP,
	MVKeyChainProtocolLDAP = kSecProtocolTypeLDAP,
	MVKeyChainProtocolAppleTalk = kSecProtocolTypeAppleTalk,
	MVKeyChainProtocolAFP = kSecProtocolTypeAFP,
	MVKeyChainProtocolTelnet = kSecProtocolTypeTelnet,
	MVKeyChainProtocolSSH = kSecProtocolTypeSSH
};


@interface MVKeyChain : NSObject
+ (MVKeyChain *) defaultKeyChain;

- (void) setGenericPassword:(NSString *) password forService:(NSString*) service account:(NSString *) account;
- (NSString *) genericPasswordForService:(NSString *) service account:(NSString *) account;
- (void) removeGenericPasswordForService:(NSString *) service account:(NSString *) account;

- (void) setInternetPassword:(NSString *) password forServer:(NSString *) server securityDomain:(NSString *) domain account:(NSString *) account path:(NSString *) path port:(unsigned short) port protocol:(MVKeyChainProtocol) protocol authenticationType:(MVKeyChainAuthenticationType) authType;
- (NSString *) internetPasswordForServer:(NSString *) server securityDomain:(NSString *) domain account:(NSString *) account path:(NSString *) path port:(unsigned short) port protocol:(MVKeyChainProtocol) protocol authenticationType:(MVKeyChainAuthenticationType) authType;
- (void) removeInternetPasswordForServer:(NSString *) server securityDomain:(NSString *) domain account:(NSString *) account path:(NSString *) path port:(unsigned short) port protocol:(MVKeyChainProtocol) protocol authenticationType:(MVKeyChainAuthenticationType) authType;
@end
