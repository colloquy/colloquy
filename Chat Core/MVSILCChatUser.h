#import "MVChatUser.h"
#import "MVChatUserPrivate.h"
#include <libsilcclient/client.h>
#include <libsilc/silcincludes.h>

NS_ASSUME_NONNULL_BEGIN

@class MVSILCChatConnection;

@interface MVSILCChatUser : MVChatUser {
	SilcClientEntry _clientEntry;
	BOOL _releasing;
}
- (id) initLocalUserWithConnection:(MVSILCChatConnection *) connection;
- (id) initWithClientEntry:(SilcClientEntry) clientEntry andConnection:(MVSILCChatConnection *) connection;
- (void) updateWithClientEntry:(SilcClientEntry) clientEntry;

- (SilcClientEntry) _getClientEntry;
@end

NS_ASSUME_NONNULL_END
