#define ENABLE(CHAT_FEATURE) (defined(ENABLE_##CHAT_FEATURE) && ENABLE_##CHAT_FEATURE)
#define USE(CHAT_FEATURE) (defined(USE_##CHAT_FEATURE) && USE_##CHAT_FEATURE)

#ifndef ENABLE_AUTO_PORT_MAPPING
#define ENABLE_AUTO_PORT_MAPPING 1
#endif

#ifndef ENABLE_SCRIPTING
#define ENABLE_SCRIPTING 1
#endif

#ifndef ENABLE_PLUGINS
#define ENABLE_PLUGINS 1
#endif

#ifndef ENABLE_IRC
#define ENABLE_IRC 1
#endif

#ifndef ENABLE_SILC
#define ENABLE_SILC 1
#endif

#ifndef ENABLE_ICB
#define ENABLE_ICB 1
#endif

#ifndef ENABLE_XMPP
#define ENABLE_XMPP 1
#endif

#import "MVChatConnection.h"

@interface NSThread (NSThreadLeopard)
- (void) cancel;
- (void) setName:(NSString *) name;
@end

#pragma mark -

@interface MVChatConnection (MVChatConnectionPrivate)
- (void) _willConnect;
- (void) _didConnect;
- (void) _didNotConnect;
- (void) _willDisconnect;
- (void) _didDisconnect;
- (void) _postError:(NSError *) error;
- (void) _setStatus:(MVChatConnectionStatus) status;

- (void) _addJoinedRoom:(MVChatRoom *) room;
- (void) _removeJoinedRoom:(MVChatRoom *) room;

- (unsigned int) _watchRulesMatchingUser:(MVChatUser *) user;
- (void) _markUserAsOnline:(MVChatUser *) user;
- (void) _markUserAsOffline:(MVChatUser *) user;
@end
