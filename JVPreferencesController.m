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

- (void) showPreferencesPanel {
	[super showPreferencesPanel];
	[_preferencesPanel setOpaque:NO]; // let us poke transparant holes in the window
}

- (void) showPreferencesPanelForOwner:(id) owner {
	[super showPreferencesPanelForOwner:owner];
	[_preferencesPanel setOpaque:NO]; // let us poke transparant holes in the window
}
@end
