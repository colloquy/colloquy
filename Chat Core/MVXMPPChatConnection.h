#import "MVChatConnection.h"
#import "MVChatConnectionPrivate.h"

@class XMPPStream;
@class XMPPJID;
@class XMPPElement;

NS_ASSUME_NONNULL_BEGIN

@interface MVXMPPChatConnection : MVChatConnection {
@private
	XMPPStream *_session;
	XMPPJID *_localID;
	unsigned short _serverPort;
	NSString *_server;
	NSString *_username;
	NSString *_nickname;
	NSString *_password;
}
#if __has_feature(objc_class_property)
@property (readonly, class, copy) NSArray<NSNumber*> *defaultServerPorts;
@property (readonly, class) NSUInteger maxMessageLength;
#else
+ (NSArray<NSNumber*> *) defaultServerPorts;
+ (NSUInteger) maxMessageLength;
#endif
@end

@interface MVXMPPChatConnection (MVXMPPChatConnectionPrivate)
- (XMPPStream *) _chatSession;
- (XMPPJID *) _localUserID;
- (XMPPElement *) _capabilitiesElement;
- (XMPPElement *) _multiUserChatExtensionElement;
@property (readonly, retain, getter=_chatSession) XMPPStream *chatSession;
@property (readonly, retain, getter=_localUserID) XMPPJID *localUserID;
@property (readonly, retain, getter=_capabilitiesElement) XMPPElement *capabilitiesElement;
@property (readonly, retain, getter=_multiUserChatExtensionElement) XMPPElement *multiUserChatExtensionElement;
@end

NS_ASSUME_NONNULL_END
