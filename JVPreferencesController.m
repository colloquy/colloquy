#import "JVPreferencesController.h"
#import <Cocoa/Cocoa.h>

@implementation JVPreferencesController
- (id) init {
	_preferenceTitles = [[NSMutableArray array] retain];
	_preferenceModules = [[NSMutableArray array] retain];
	return self;
}

- (BOOL) usesButtons {
	return NO;
}

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_2
#define _preferencesPanel (id)0
#endif

- (void) showPreferencesPanel {
	[super showPreferencesPanel];
	// let us poke transparant holes in the window
	if( NSAppKitVersionNumber >= 700. ) [_preferencesPanel setOpaque:NO];
}

- (void) showPreferencesPanelForOwner:(id) owner {
	[super showPreferencesPanelForOwner:owner];
	// let us poke transparant holes in the window
	if( NSAppKitVersionNumber >= 700. ) [_preferencesPanel setOpaque:NO];
}
@end