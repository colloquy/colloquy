// Created by Mike Shields on 10/9/05.

#import "JVSpeechController.h"

@implementation JVSpeechController
+ (JVSpeechController*) sharedSpeechController {
	static JVSpeechController *sharedSpeechController = nil;
	if( ! sharedSpeechController ) sharedSpeechController = [[JVSpeechController alloc] init];
	return sharedSpeechController;
}

- (id) init {
	if( ( self = [super init] ) ) {
		_speechQueue = [[NSMutableArray alloc] initWithCapacity:15];
		_synthesizers = [[NSArray alloc] initWithObjects:[[[NSSpeechSynthesizer alloc] initWithVoice:nil] autorelease], [[[NSSpeechSynthesizer alloc] initWithVoice:nil] autorelease], [[[NSSpeechSynthesizer alloc] initWithVoice:nil] autorelease], nil];

		for( NSSpeechSynthesizer *synthesizer in _synthesizers )
			synthesizer.delegate = self;
	}

	return self;
}

- (void) dealloc {
	[_speechQueue release];
	[_synthesizers release];

	_speechQueue = nil;
	_synthesizers = nil;

	[super dealloc];
}

- (void) startSpeakingString:(NSString *) string usingVoice:(NSString *) voice {

	for( NSSpeechSynthesizer *synth in _synthesizers ) {
		if( ! [synth isSpeaking] ) {
			[synth setVoice:voice];
			[synth startSpeakingString:string];
			return;
		}
	}

	// Limit the number of outstanding strings to 15. This will prevent massive amounts of TTS flooding
	// when you get a channel flood or re-connect to a dircproxy server. Remove the oldest string from
	// the queue and then insert the new string onto the end.
	if( [_speechQueue count] > 15 )
		[_speechQueue removeObjectAtIndex:0];

	[_speechQueue addObject:[NSDictionary dictionaryWithObjectsAndKeys:string, @"text", voice, @"voice", nil]];
}

- (void) speechSynthesizer:(NSSpeechSynthesizer *) sender didFinishSpeaking:(BOOL) finishedSpeaking {
	if( [_speechQueue count] ) {
		NSDictionary *nextSpeech = [_speechQueue objectAtIndex:0];
		[nextSpeech retain];
		[_speechQueue removeObjectAtIndex:0];
		[sender setVoice:[nextSpeech objectForKey:@"voice"]];
		[sender startSpeakingString:[nextSpeech objectForKey:@"text"]];
		[nextSpeech release];
	}
}
@end
