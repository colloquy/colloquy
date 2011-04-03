#import "CQDaemonClientConnectionController.h"

#import "CQColloquyDaemon.h"
#import "CQDaemonLocalClientConnection.h"

@implementation CQDaemonClientConnectionController
+ (CQDaemonClientConnectionController *) defaultController {
	static BOOL creatingSharedInstance = NO;
	static CQDaemonClientConnectionController *sharedInstance = nil;

	if (!sharedInstance && !creatingSharedInstance) {
		creatingSharedInstance = YES;
		sharedInstance = [[self alloc] init];
	}

	return sharedInstance;
}

#pragma mark -

- (id) init {
	if (!(self = [super init]))
		return nil;

	_clientConnections = [[NSMutableSet alloc] initWithCapacity:5];

	_localServerConnection = [[NSConnection alloc] init];
	[_localServerConnection setRootObject:[NSNull null]];
	[_localServerConnection addRunLoop:[NSRunLoop currentRunLoop]];
	[_localServerConnection setDelegate:self];

	NSString *serverName = [NSString stringWithFormat:@"info.colloquy.daemon - %@", NSUserName()];
	if (![_localServerConnection registerName:serverName]) {
		[_localServerConnection invalidate];

		MVSafeAdoptAssign(_localServerConnection, nil);

		[self release];

		@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Connection could not be registered. Another process likely has registered with the same name." userInfo:nil];
	}

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(close) name:CQColloquyDaemonWillTerminateNotification object:nil];

	return self;
}

- (void) dealloc {
	NSAssert(!_localServerConnection, @"_localServerConnection should be nil");

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_clientConnections release];

	[super dealloc];
}

#pragma mark -

- (void) addClientConnection:(CQDaemonClientConnection *) clientConnection {
	NSParameterAssert(clientConnection);

	[[CQColloquyDaemon sharedDaemon] disableAutomaticTermination];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clientConnectionDidClose:) name:CQDaemonClientConnectionDidCloseNotification object:clientConnection];

	[_clientConnections addObject:clientConnection];
}

- (void) removeClientConnection:(CQDaemonClientConnection *) clientConnection {
	NSParameterAssert(clientConnection);

	[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:clientConnection];

	[_clientConnections removeObject:clientConnection];

	[[CQColloquyDaemon sharedDaemon] enableAutomaticTermination];
}

#pragma mark -

- (void) clientConnectionDidClose:(NSNotification *) notification {
	[self removeClientConnection:notification.object];
}

#pragma mark -

- (void) close {
	NSSet *clientConnectionsCopy = [_clientConnections copy];
	[clientConnectionsCopy makeObjectsPerformSelector:@selector(close)];
	[clientConnectionsCopy release];

	[_localServerConnection invalidate];

	MVSafeAdoptAssign(_localServerConnection, nil);
}

#pragma mark -

- (BOOL) connection:(NSConnection *) serverConnection shouldMakeNewConnection:(NSConnection *) incommingConnection {
	CQDaemonLocalClientConnection *clientConnection = [[CQDaemonLocalClientConnection alloc] initWithConnection:incommingConnection];
	[self addClientConnection:clientConnection];
	[clientConnection release];

	return YES;
}
@end
