#import <AudioToolbox/AudioServices.h>

@interface CQSoundController : NSObject {
	SystemSoundID _sound;
}
- (id) initWithSoundNamed:(NSString *) soundName;

- (void) playAlert;
- (void) playSound;
@end
