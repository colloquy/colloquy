#import <Cocoa/Cocoa.h>
#import "JVNotificationController.h"
#import "MVApplicationController.h"

static JVNotificationController *sharedInstance = nil;

@interface JVNotificationController (JVNotificationControllerPrivate)
- (void) _bounceIconOnce;
- (void) _bounceIconContinuously;
- (void) _playSound:(NSString *) path;
- (void) _threadPlaySound:(NSString *) path;
@end

#pragma mark -

@implementation JVNotificationController
+ (JVNotificationController *) defaultManager {
	extern JVNotificationController *sharedInstance;
	if( ! sharedInstance && [MVApplicationController isTerminating] ) return nil;
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] init] ) );
}

#pragma mark -

- (id) init {
	self = [super init];
	return self;
}

- (void) dealloc {
	extern JVNotificationController *sharedInstance;

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if( self == sharedInstance ) sharedInstance = nil;

	[super dealloc];
}

- (void) performNotification:(NSString *) identifier withContextInfo:(NSDictionary *) context {
	NSDictionary *eventPrefs = [[NSUserDefaults standardUserDefaults] dictionaryForKey:[NSString stringWithFormat:@"JVNotificationSettings %@", identifier]];

	if( [[eventPrefs objectForKey:@"playSound"] boolValue] )
		[self _playSound:[eventPrefs objectForKey:@"soundPath"]];

	if( [[eventPrefs objectForKey:@"bounceIconUntilFront"] boolValue] )
		[self _bounceIconContinuously];
	else if( [[eventPrefs objectForKey:@"bounceIcon"] boolValue] )
		[self _bounceIconOnce];
}
@end

#pragma mark -

@implementation JVNotificationController (JVNotificationControllerPrivate)
- (void) _bounceIconOnce {
	[[NSApplication sharedApplication] requestUserAttention:NSInformationalRequest];
}

- (void) _bounceIconContinuously {
	[[NSApplication sharedApplication] requestUserAttention:NSCriticalRequest];
}

- (void) _playSound:(NSString *) path {
	if( ! path ) return;
	[NSThread detachNewThreadSelector:@selector( _threadPlaySound: ) toTarget:self withObject:path];
}

- (void) _threadPlaySound:(NSString *) path {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	if( ! [path isAbsolutePath] ) path = [[NSString stringWithFormat:@"%@/Sounds", [[NSBundle mainBundle] resourcePath]] stringByAppendingPathComponent:path];

	NSSound *sound = [[NSSound alloc] initWithContentsOfFile:path byReference:YES];
	[sound setDelegate:self];

// When run on a laptop using battery power, the play method may block while the audio
// hardware warms up.  If it blocks, the sound WILL NOT PLAY after the block ends.
// To get around this, we check to make sure the sound is playing, and if it isn't
// we call the play method again.

	[sound play];
	if( ! [sound isPlaying] ) [sound play];

	[pool release];
}

- (void) sound:(NSSound *) sound didFinishPlaying:(BOOL) finish {
	[sound autorelease];
}
@end