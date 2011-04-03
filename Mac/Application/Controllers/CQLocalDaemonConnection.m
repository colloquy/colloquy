#import "CQLocalDaemonConnection.h"

#import "CQDaemonConnectionPrivate.h"

@implementation CQLocalDaemonConnection
- (id) init {
	if (!(self = [super init]))
		return nil;

	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(daemonFinishedLaunching:) name:@"info.colloquy.daemon.finishedLaunching" object:NSUserName() suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];

	return self;
}

- (void) dealloc {
	NSAssert(!_connection, @"_connection should be nil");

	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];

	[super dealloc];
}

#pragma mark -

- (void) launchDaemon {
	if (_launchingDaemon)
		return;

	_launchingDaemon = YES;

	NSString *path = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"ColloquyDaemon"];
	[NSTask launchedTaskWithLaunchPath:path arguments:[NSArray array]];
}

- (void) daemonFinishedLaunching:(NSNotification *) notification {
	[self connect];

	_launchingDaemon = NO;
}

#pragma mark -

- (void) connect {
	if (_connection)
		return;

	[super connect];

	NSString *serverName = [NSString stringWithFormat:@"info.colloquy.daemon - %@", NSUserName()];
	_connection = [[NSConnection connectionWithRegisteredName:serverName host:nil] retain];

	if (!_connection) {
		[self launchDaemon];
		return;
	}

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionDidDie:) name:NSConnectionDidDieNotification object:_connection];

	[_connection setRootObject:self];
	[[_connection rootProxy] setProtocolForProxy:@protocol(CQColloquyDaemon)];

	[self _didConnect];
}

- (void) close {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSConnectionDidDieNotification object:_connection];

	[_connection invalidate];

	MVSafeAdoptAssign(_connection, nil);

	[super close];
}

#pragma mark -

- (void) connectionDidDie:(NSNotification *) notification {
	[self close];
	[self connect];
}

#pragma mark -

- (id <CQColloquyDaemon>) daemon {
	return (id <CQColloquyDaemon>)[_connection rootProxy];
}
@end
