#import "JVFileTransferPreferences.h"

@implementation JVFileTransferPreferences
- (NSString *) preferencesNibName {
	return @"JVFileTransferPreferences";
}

- (BOOL) hasChangesPending {
	return NO;
}

- (NSImage *) imageForPreferenceNamed:(NSString *) name {
	return [[[NSImage imageNamed:@"FileTransferPreferences"] retain] autorelease];
}

- (BOOL) isResizable {
	return NO;
}

- (void) initializeFromDefaults {
	
}
@end
