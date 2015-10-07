#import <AudioToolbox/AudioServices.h>

NS_ASSUME_NONNULL_BEGIN

@interface CQSoundController : NSObject
+ (void) vibrate;

- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithSoundNamed:(NSString *) soundName NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) NSString *soundName;

- (void) playSound;
@end

NS_ASSUME_NONNULL_END
