#import "CQColloquyApplication.h"

@implementation CQColloquyApplication
+ (CQColloquyApplication *) sharedApplication {
	return (CQColloquyApplication *)[super sharedApplication];
}

#pragma mark -

- (id) init {
	if (!(self = [super init]))
		return nil;

	self.delegate = self;

	_launchDate = [[NSDate alloc] init];

	return self;
}

- (void) dealloc {
	[_launchDate release];

	[super dealloc];
}

#pragma mark -

@synthesize launchDate = _launchDate;

#pragma mark -

- (void) applicationDidFinishLaunching:(NSNotification *) notification {
	// Do stuff here.
}
@end
