// Created by Mike Shields on 10/9/05.

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

COLLOQUY_EXPORT
@interface JVSpeechController : NSObject <NSSpeechSynthesizerDelegate> {
	NSMutableArray<NSDictionary<NSString*, NSString*>*> *_speechQueue;
	NSArray<NSSpeechSynthesizer*> *_synthesizers;
}
#if __has_feature(objc_class_property)
@property (readonly, strong, class) JVSpeechController *sharedSpeechController;
#else
+ (JVSpeechController *) sharedSpeechController;
#endif
- (void) startSpeakingString:(NSString *) string usingVoice:(NSString *) voice;
@end

NS_ASSUME_NONNULL_END
