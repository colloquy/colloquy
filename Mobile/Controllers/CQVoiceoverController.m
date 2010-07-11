// Speak the message if the room is in the foreground
// Otherwise, only speak the message if its a highlight

#import "CQVoiceoverController.h"

static BOOL voiceoverRunning;

@implementation CQVoiceoverController
- (void) _voiceoverStatusChanged {
	voiceoverRunning = UIAccessibilityIsVoiceOverRunning();
}

#pragma mark -

- (id) init {
	if (![[UIDevice currentDevice] isSystemFour])
		return nil;

	if (!(self = [super init]))
		return nil;

	voiceoverRunning = UIAccessibilityIsVoiceOverRunning();

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_voiceoverStatusChanged) name:UIAccessibilityVoiceOverStatusChanged object:nil];

	return self;
}

+ (CQVoiceoverController *) defaultController {
	if (![[UIDevice currentDevice] isSystemFour])
		return nil;

	static BOOL creatingSharedInstance = NO;
	static CQVoiceoverController *sharedInstance = nil;

	if (!voiceoverRunning) // don't run if voiceover is disabled
		return nil;

	if (!sharedInstance && !creatingSharedInstance) {
		creatingSharedInstance = YES;
		sharedInstance = [[self alloc] init];
	}

	return sharedInstance;
}

#pragma mark -

- (void) _postNotificationWithArgument:(NSString *) argument {
	UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, argument);
	[argument release];
}

#pragma mark -

- (void) _postNotificationWithMessage:(NSString *) message user:(NSString *) user channel:(NSString *) channel privately:(BOOL) privately {
	NSString *argument = nil;
	if (channel.length)
		argument = [[NSString alloc] initWithFormat:@"%@, %@: %@", channel, user, message];
	else if (privately)
		argument = [[NSString alloc] initWithFormat:@"%@: %@", user, message];
	else argument = [[NSString alloc] initWithFormat:@"%@: %@", user, message];

	[self performSelectorOnMainThread:@selector(_postNotificationWithArgument:) withObject:argument waitUntilDone:NO];
}

- (void) postNotificationWithMessage:(NSString *) message user:(NSString *) user channel:(NSString *) channel {
	[self _postNotificationWithMessage:message user:user channel:channel privately:NO];
}

- (void) postNotificationWithMessage:(NSString *) message user:(NSString *) user privately:(BOOL) privately {
	[self _postNotificationWithMessage:message user:user channel:nil privately:privately];
}
@end
