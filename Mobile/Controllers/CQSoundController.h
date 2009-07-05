#import <AudioToolbox/AudioServices.h>

@interface CQSoundController : NSObject {
	SystemSoundID _sound;
	NSTimeInterval _previousAlertTime;
}
+ (void) vibrate;

- (id) initWithSoundNamed:(NSString *) soundName;

- (void) playAlert;
- (void) playSound;
@end
