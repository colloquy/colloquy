#import <AudioToolbox/AudioServices.h>

@interface CQSoundController : NSObject {
	SystemSoundID _sound;
	NSTimeInterval _previousPlayTime;
}
+ (void) vibrate;

- (id) initWithSoundNamed:(NSString *) soundName;

- (void) playSound;
@end
