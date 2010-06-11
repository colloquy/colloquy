#import "CQSoundController.h"

@implementation CQSoundController
+ (void) vibrate {
	static NSTimeInterval previousVibrateTime = 0.;

	NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
	if ((currentTime - previousVibrateTime) < 2.)
		return;

	previousVibrateTime = currentTime;

	AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

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

	_soundName = [soundName copy];
	_previousPlayTime = 0.;

	return self;
}

- (void) dealloc {
	AudioServicesDisposeSystemSoundID(_sound);

	[_soundName release];

	[super dealloc];
}

@synthesize soundName = _soundName;

- (void) playSound {
	NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
	if ((currentTime - _previousPlayTime) < 2.)
		return;

	_previousPlayTime = currentTime;
	
	if ([[UIDevice currentDevice] isPodModel])
		AudioServicesPlayAlertSound(_sound);
	else AudioServicesPlaySystemSound(_sound);
}
@end
