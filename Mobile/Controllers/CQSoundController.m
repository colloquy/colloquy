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

- (instancetype) initWithSoundNamed:(NSString *) soundName {
	NSParameterAssert(soundName);

	if (!(self = [super init]))
		return nil;

	_soundName = [soundName copy];

	return self;
}

- (void) dealloc {
	AudioServicesDisposeSystemSoundID(_sound);
}

- (void) playSound {
	if (!_sound) {
		if (!_soundName.length)
			return;

		NSString *pathString = [[NSBundle mainBundle] pathForResource:_soundName ofType:@"aiff"];
		if (!pathString.length)
			return;

		NSURL *path = [NSURL fileURLWithPath:pathString];
		if (!path)
			return;

		OSStatus error = AudioServicesCreateSystemSoundID((__bridge CFURLRef)path, &_sound);
		if (error != kAudioServicesNoError) {
			if (_sound)
				AudioServicesDisposeSystemSoundID(_sound);
			return;
		}
	}

	NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
	if ((currentTime - _previousPlayTime) < 2.)
		return;

	_previousPlayTime = currentTime;

	AudioServicesPlaySystemSound(_sound);
}
@end
