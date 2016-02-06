// Created by Mike Shields on 10/9/05.

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface JVSpeechController : NSObject <NSSpeechSynthesizerDelegate> {
	NSMutableArray<NSDictionary<NSString*, NSString*>*> *_speechQueue;
	NSArray<NSSpeechSynthesizer*> *_synthesizers;
}
+ (JVSpeechController *) sharedSpeechController;
- (void) startSpeakingString:(NSString *) string usingVoice:(NSString *) voice;
@end

NS_ASSUME_NONNULL_END
