#import <Security/Security.h>
#import <Foundation/Foundation.h>

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

- (NSString *) genericPasswordForService:(NSString *) service account:(NSString *) account;
- (void) removeGenericPasswordForService:(NSString *) service account:(NSString *) account;

- (NSString *) internetPasswordForServer:(NSString *) server securityDomain:(NSString *) domain account:(NSString *) account path:(NSString *) path port:(unsigned short) port protocol:(MVKeyChainProtocol) protocol authenticationType:(MVKeyChainAuthenticationType) authType;
- (void) removeInternetPasswordForServer:(NSString *) server securityDomain:(NSString *) domain account:(NSString *) account path:(NSString *) path port:(unsigned short) port protocol:(MVKeyChainProtocol) protocol authenticationType:(MVKeyChainAuthenticationType) authType;
@end
