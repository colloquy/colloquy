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
		return nil;
	}

	NSString *pathString = [[NSBundle mainBundle] pathForResource:soundName ofType:@"aiff"];
	if (!pathString.length) {
		return nil;
	}

	NSURL *path = [[NSURL fileURLWithPath:pathString] absoluteURL];

	if (!(self = [super init]))
		return nil;

	if (path) {
		OSStatus error = AudioServicesCreateSystemSoundID((__bridge CFURLRef)path, &_sound);
		if (error != kAudioServicesNoError) {
			return nil;
		}
	} else {
		return nil;
	}

	_soundName = [soundName copy];
	_previousPlayTime = 0.;

	return self;
}

- (void) dealloc {
	AudioServicesDisposeSystemSoundID(_sound);
}

- (void) playSound {
	NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
	if ((currentTime - _previousPlayTime) < 2.)
		return;

	_previousPlayTime = currentTime;

	AudioServicesPlaySystemSound(_sound);
}
@end
