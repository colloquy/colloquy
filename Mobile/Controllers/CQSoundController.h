#import <AudioToolbox/AudioToolbox.h>

@interface CQSoundController : NSObject {
	SystemSoundID _sound;
}

- (id) initWithContentsOfSoundNamed:(NSString *)alert;

- (void) playAlert;

@end
