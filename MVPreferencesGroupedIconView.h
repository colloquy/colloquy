#import <AppKit/NSView.h>
#import <AppKit/NSNibDeclarations.h>

@class MVPreferencesController;
@class NSBundle;
@class NSArray;
@class NSMutableArray;

extern const unsigned int groupViewHeight, multiIconViewYOffset;

@interface MVPreferencesGroupedIconView : NSView {
	MVPreferencesController *preferencesController;
	NSArray *preferencePanes, *preferencePaneGroups;
	NSMutableArray *groupMultiIconViews;
}
- (void) setPreferencesController:(MVPreferencesController *) newPreferencesController;

- (void) setPreferencePanes:(NSArray *) newPreferencePanes;
- (NSArray *) preferencePanes;

- (void) setPreferencePaneGroups:(NSArray *) newPreferencePaneGroups;
- (NSArray *) preferencePaneGroups;
@end
