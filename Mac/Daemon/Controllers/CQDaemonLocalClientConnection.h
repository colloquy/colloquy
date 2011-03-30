#import "CQDaemonClientConnection.h"

@interface CQDaemonLocalClientConnection : CQDaemonClientConnection {
@private
    NSConnection *_connection;
}
- (id) initWithConnection:(NSConnection *) connection;
@end
