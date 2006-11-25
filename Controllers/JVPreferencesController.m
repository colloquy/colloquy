#import "JVPreferencesController.h"

@interface NSWindow (NSWindowPrivate) // new Tiger private method
- (void) _setContentHasShadow:(BOOL) shadow;
@end

#pragma mark -

@implementation JVPreferencesController
- (id) init {
	_preferenceTitles = [[NSMutableArray array] retain];
	_preferenceModules = [[NSMutableArray array] retain];
	_currentSessionPreferenceViews = [[NSMutableDictionary dictionary] retain];
	_masterPreferenceViews = [[NSMutableDictionary dictionary] retain];
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
	[_preferencesPanel setOpaque:NO]; // let us poke transparant holes in the window
	if( [_preferencesPanel respondsToSelector:@selector( _setContentHasShadow: )] )
		[_preferencesPanel _setContentHasShadow:NO]; // this is new in Tiger
	if( [_preferencesPanel respondsToSelector:@selector( setShowsToolbarButton: )] )
		[_preferencesPanel setShowsToolbarButton:NO];
}

- (void) showPreferencesPanelForOwner:(id) owner {
	[super showPreferencesPanelForOwner:owner];
	[_preferencesPanel setOpaque:NO]; // let us poke transparant holes in the window
	if( [_preferencesPanel respondsToSelector:@selector( _setContentHasShadow: )] )
		[_preferencesPanel _setContentHasShadow:NO]; // this is new in Tiger
	if( [_preferencesPanel respondsToSelector:@selector( setShowsToolbarButton: )] )
		[_preferencesPanel setShowsToolbarButton:NO];
}
@end
