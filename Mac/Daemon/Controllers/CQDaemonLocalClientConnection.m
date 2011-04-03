#import "CQDaemonLocalClientConnection.h"

#import "CQDaemonClientConnectionPrivate.h"

@implementation CQDaemonLocalClientConnection
- (id) initWithConnection:(NSConnection *) connection {
	if (!(self = [super init]))
		return nil;

	_connection = [connection retain];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionDidDie:) name:NSConnectionDidDieNotification object:_connection];

	[_connection setRootObject:self];
	[[_connection rootProxy] setProtocolForProxy:@protocol(CQColloquyClient)];

	[self _didConnect];

	return self;
}

- (void) dealloc {
	NSAssert(!_connection, @"_connection should be nil");

	[super dealloc];
}

#pragma mark -

- (void) close {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSConnectionDidDieNotification object:_connection];

	[_connection invalidate];

	MVSafeAdoptAssign(_connection, nil);

	[super close];
}

#pragma mark -

- (void) connectionDidDie:(NSNotification *) notification {
	[self close];
}

#pragma mark -

- (id <CQColloquyClient>) client {
	return (id <CQColloquyClient>)[_connection rootProxy];
}
@end
