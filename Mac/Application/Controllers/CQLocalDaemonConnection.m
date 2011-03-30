#import "CQLocalDaemonConnection.h"

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
	if (_daemonRunning)
		return;

	_daemonRunning = YES;

	NSString *path = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"ColloquyDaemon"];
	[NSTask launchedTaskWithLaunchPath:path arguments:[NSArray array]];
}

- (void) daemonFinishedLaunching:(NSNotification *) notification {
	[self connect];
}

#pragma mark -

- (void) connect {
	[super connect];

	NSString *serverName = [NSString stringWithFormat:@"info.colloquy.daemon - %@", NSUserName()];
	_connection = [NSConnection connectionWithRegisteredName:serverName host:nil];

	if (!_connection) {
		[self launchDaemon];
		return;
	}

	// Asking for the rootProxy causes the connection to really connect.
	[_connection rootProxy];

	_daemonRunning = YES;
}

- (void) close {
	[_connection invalidate];
	[_connection release];
	_connection = nil;

	[super close];
}
@end
