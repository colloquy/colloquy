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

typedef SecProtocolType MVKeyChainProtocol;

NS_ASSUME_NONNULL_BEGIN


COLLOQUY_EXPORT
@interface MVKeyChain : NSObject
#if __has_feature(objc_class_property)
@property (class, readonly, retain) MVKeyChain *defaultKeyChain;
#else
+ (MVKeyChain *) defaultKeyChain;
#endif

- (nullable NSString *) genericPasswordForService:(nullable NSString *) service account:(nullable NSString *) account;
- (void) removeGenericPasswordForService:(NSString *) service account:(NSString *) account;

- (nullable NSString *) internetPasswordForServer:(NSString *) server securityDomain:(NSString *) domain account:(nullable NSString *) account path:(nullable NSString *) path port:(unsigned short) port protocol:(MVKeyChainProtocol) protocol authenticationType:(MVKeyChainAuthenticationType) authType;
- (void) removeInternetPasswordForServer:(NSString *) server securityDomain:(nullable NSString *) domain account:(nullable NSString *) account path:(nullable NSString *) path port:(unsigned short) port protocol:(MVKeyChainProtocol) protocol authenticationType:(MVKeyChainAuthenticationType) authType;
@end

NS_ASSUME_NONNULL_END
