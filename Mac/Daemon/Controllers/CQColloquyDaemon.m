#import "CQColloquyDaemon.h"

#import "CQDaemonClientConnectionController.h"

#import <sandbox.h>

NSString * const CQColloquyDaemonWillTerminateNotification = @"CQColloquyDaemonWillTerminateNotification";

@implementation CQColloquyDaemon
+ (CQColloquyDaemon *) sharedDaemon {
	static BOOL creatingSharedInstance = NO;
	static CQColloquyDaemon *sharedInstance = nil;

	if (!sharedInstance && !creatingSharedInstance) {
		creatingSharedInstance = YES;
		sharedInstance = [[self alloc] init];
	}

	return sharedInstance;
}

#pragma mark -

- (void) enterSandbox {
	NSString *sandboxProfilePath = [[NSBundle mainBundle] pathForResource:@"ColloquyDaemon" ofType:@"sb"];
	if (!sandboxProfilePath.length) {
		fprintf(stderr, "Sandbox profile 'ColloquyDaemon.sb' was not found.");
		exit(EXIT_FAILURE);
	}

	NSString *sandboxProfile = [NSString stringWithContentsOfFile:sandboxProfilePath encoding:NSUTF8StringEncoding error:NULL];
	if (!sandboxProfile.length) {
		fprintf(stderr, "Sandbox profile '%s' is empty.", [sandboxProfilePath fileSystemRepresentation]);
		exit(EXIT_FAILURE);
	}

	char *error = NULL;
	if (sandbox_init([sandboxProfile UTF8String], 0, &error)) {
		fprintf(stderr, "Failed to initialize sandbox profile '%s'. Due to error: %s.", [sandboxProfilePath fileSystemRepresentation], error);
		sandbox_free_error(error);
		exit(EXIT_FAILURE);
	}
}

- (void) run {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	_running = YES;

	[self enterSandbox];

	[CQDaemonClientConnectionController defaultController];

	[[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"info.colloquy.daemon.finishedLaunching" object:NSUserName() userInfo:nil deliverImmediately:YES];

	[pool drain];

	NSRunLoop *runloop = [NSRunLoop currentRunLoop];
	while (_running)
		[runloop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];

	[[NSNotificationCenter defaultCenter] postNotificationName:CQColloquyDaemonWillTerminateNotification object:self];

	// Run the runloop one last time to let any notification observers do last minute work.
	[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantPast]];
}

- (void) terminate {
	_running = NO;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(terminate) object:nil];

	CFRunLoopStop([[NSRunLoop currentRunLoop] getCFRunLoop]);
}

- (void) disableAutomaticTermination {
	if (!_running)
		return;

	++_disableAutomaticTerminationCount;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(terminate) object:nil];
}

- (void) enableAutomaticTermination {
	if (!_running)
		return;

	NSAssert(_disableAutomaticTerminationCount, @"_disableAutomaticTerminationCount should not be 0");
	if (_disableAutomaticTerminationCount)
		--_disableAutomaticTerminationCount;

	if (_disableAutomaticTerminationCount)
		return;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(terminate) object:nil];
	[self performSelector:@selector(terminate) withObject:nil afterDelay:0.];
}
@end

#pragma mark -

int CQColloquyDaemonMain(int argc, const char *argv[]) {
	@try {
		[[CQColloquyDaemon sharedDaemon] run];
	} @catch (id exception) {
		fprintf(stderr, "%s", [[exception description] UTF8String]);
		return EXIT_FAILURE;
	}

	return EXIT_SUCCESS;
}
