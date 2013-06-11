#import "CQColloquyApplication.h"

#import "CQDaemonConnectionController.h"

@implementation CQColloquyApplication
+ (CQColloquyApplication *) sharedApplication {
	return (CQColloquyApplication *)[super sharedApplication];
}

#pragma mark -

- (id) init {
	if (!(self = [super init]))
		return nil;

	self.delegate = self;

	_launchDate = [NSDate date];

	return self;
}

#pragma mark -

@synthesize launchDate = _launchDate;

#pragma mark -

- (void) applicationWillFinishLaunching:(NSNotification *) notification {
	[CQDaemonConnectionController defaultController];
}

- (void) applicationDidFinishLaunching:(NSNotification *) notification {
	// Do stuff here.
}
@end
