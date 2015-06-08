#import <AudioToolbox/AudioServices.h>

@interface CQSoundController : NSObject {
	SystemSoundID _sound;
	NSTimeInterval _previousPlayTime;
	NSString *_soundName;
}
+ (void) vibrate;

- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithSoundNamed:(NSString *) soundName NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) NSString *soundName;

- (void) playSound;
@end
