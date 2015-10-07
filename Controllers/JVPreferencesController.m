#import "JVPreferencesController.h"

#include <dlfcn.h>

@interface NSWindow (NSWindowPrivate) // new Tiger private method
- (void) _setContentHasShadow:(BOOL) shadow;
@end

#pragma mark -

@implementation JVPreferencesController
+ (void)initialize {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		void *handle = dlopen("/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit", RTLD_LOCAL | RTLD_LAZY);
		if (handle != NULL) {
			void  (*fptr)(void);
			fptr = (void (*)(void))dlsym(handle, "_enableNSPreferences");

			if (fptr != NULL) {
				fptr();
			} else {
				NSLog(@"unable to enable preferences");
			}
		} else {
			NSLog(@"unable to load preferences framework");
		}
	});
}

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
