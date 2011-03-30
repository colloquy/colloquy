#import "CQDaemonLocalClientConnection.h"

@implementation CQDaemonLocalClientConnection
- (id) initWithConnection:(NSConnection *) connection {
	if (!(self = [super init]))
		return nil;

	_connection = [connection retain];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionDidDie:) name:NSConnectionDidDieNotification object:_connection];

	return self;
}

- (void) dealloc {
	NSAssert(!_connection, @"_connection should be nil");

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[super dealloc];
}

#pragma mark -

- (void) close {
	[_connection invalidate];
	[_connection release];
	_connection = nil;

	[super close];
}

#pragma mark -

- (void) connectionDidDie:(NSNotification *) notification {
	[self close];
}
@end
