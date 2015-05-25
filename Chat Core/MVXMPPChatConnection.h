#import "MVChatConnection.h"
#import "MVChatConnectionPrivate.h"

@class JabberSession;
@class JabberID;
@class XMLElement;

NS_ASSUME_NONNULL_BEGIN

@interface MVXMPPChatConnection : MVChatConnection {
@private
	JabberSession *_session;
	JabberID *_localID;
	unsigned short _serverPort;
	NSString *_server;
	NSString *_username;
	NSString *_nickname;
	NSString *_password;
}
+ (NSArray *) defaultServerPorts;
@end

@interface MVXMPPChatConnection (MVXMPPChatConnectionPrivate)
- (JabberSession *) _chatSession;
- (JabberID *) _localUserID;
- (XMLElement *) _capabilitiesElement;
- (XMLElement *) _multiUserChatExtensionElement;
@end

NS_ASSUME_NONNULL_END
