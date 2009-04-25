#import "CQSoundController.h"

@implementation CQSoundController
- (id) initWithContentsOfSoundNamed:(NSString *) alert {
	NSURL *path = [[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:alert ofType:@"aiff"]] absoluteURL];
	
	if ( !( self = [self init] ) )
		return nil;

	if ( path ) {
		OSStatus error = AudioServicesCreateSystemSoundID((CFURLRef)path, &_sound);
		
		if ( error != kAudioServicesNoError ) {
			[self release];
			return nil;
		}
	} else {
		[self release];
		return nil;
	}
	return self;
}

- (void) playAlert {
	AudioServicesPlayAlertSound(_sound);
}

- (void) dealloc {
	AudioServicesDisposeSystemSoundID(_sound);
	[super dealloc];
}
@end
