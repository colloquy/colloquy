#import "CQSoundController.h"

@implementation CQSoundController
- (id) initWithSoundNamed:(NSString *) soundName {
	if (!soundName.length) {
		[self release];
		return nil;
	}

	NSString *pathString = [[NSBundle mainBundle] pathForResource:soundName ofType:@"aiff"];
	if (!pathString.length) {
		[self release];
		return nil;
	}

	NSURL *path = [[NSURL fileURLWithPath:pathString] absoluteURL];

	if (!(self = [self init]))
		return nil;

	if (path) {
		OSStatus error = AudioServicesCreateSystemSoundID((CFURLRef)path, &_sound);
		if (error != kAudioServicesNoError) {
			[self release];
			return nil;
		}
	} else {
		[self release];
		return nil;
	}

	return self;
}

- (void) playAlert {
	AudioServicesPlayAlertSound(_sound);
}

- (void) playSound {
	AudioServicesPlaySystemSound(_sound);
}

- (void) dealloc {
	AudioServicesDisposeSystemSoundID(_sound);
	[super dealloc];
}
@end
