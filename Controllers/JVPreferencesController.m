#import "JVPreferencesController.h"

@interface NSWindow (NSWindowPrivate) // new Tiger private method
- (void) _setContentHasShadow:(BOOL) shadow;
@end

#pragma mark -

@implementation JVPreferencesController
- (id) init {
	if (!(self = [super init]))
		return nil;

	_preferenceTitles = [NSMutableArray array];
	_preferenceModules = [NSMutableArray array];
	_currentSessionPreferenceViews = [NSMutableDictionary dictionary];
	_masterPreferenceViews = [NSMutableDictionary dictionary];

	return self;
}

- (BOOL) usesButtons {
	return NO;
}

- (void) showPreferencesPanel {
	[super showPreferencesPanel];
	[_preferencesPanel setOpaque:NO]; // let us poke transparant holes in the window
	if( [_preferencesPanel respondsToSelector:@selector( _setContentHasShadow: )] )
		[_preferencesPanel _setContentHasShadow:NO]; // this is new in Tiger
	[_preferencesPanel setShowsToolbarButton:NO];
}

- (void) showPreferencesPanelForOwner:(id) owner {
	[super showPreferencesPanelForOwner:owner];
	[_preferencesPanel setOpaque:NO]; // let us poke transparant holes in the window
	if( [_preferencesPanel respondsToSelector:@selector( _setContentHasShadow: )] )
		[_preferencesPanel _setContentHasShadow:NO]; // this is new in Tiger
	[_preferencesPanel setShowsToolbarButton:NO];
}
@end
