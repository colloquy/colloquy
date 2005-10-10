// Created by Mike Shields on 10/9/05.

@interface JVSpeechController : NSObject {
	NSMutableArray *_speechQueue;
	NSArray *_synthesizers;
}
+ (JVSpeechController*) sharedSpeechController;
- (void) startSpeakingString:(NSString *) string usingVoice:(NSString *) voice;
@end
