#import <AudioToolbox/AudioServices.h>

@interface CQSoundController : NSObject {
	SystemSoundID _sound;
	NSTimeInterval _previousPlayTime;
	NSString *_soundName;
}
+ (void) vibrate;

- (id) initWithSoundNamed:(NSString *) soundName;

@property (nonatomic, readonly) NSString *soundName;

- (void) playSound;
@end
