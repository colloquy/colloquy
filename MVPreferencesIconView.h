#import <AppKit/NSView.h>
#import <AppKit/NSNibDeclarations.h>

@class MVPreferencesController;
@class NSBundle;
@class NSArray;

extern const NSSize buttonSize, iconSize;
extern const unsigned int titleBaseline, iconBaseline, bottomBorder;

@interface MVPreferencesIconView : NSView {
	MVPreferencesController *preferencesController;
	NSBundle *selectedPane;
	NSArray *preferencePanes;
	unsigned int pressedIconIndex, focusedIndex;
	BOOL preferencesControllerSet;
	int tag;
}
- (void) setPreferencesController:(MVPreferencesController *) newPreferencesController;

- (void) setPreferencePanes:(NSArray *) newPreferencePanes;
- (NSArray *) preferencePanes;

- (void) setSelectedPane:(NSBundle *) newSelectedClientRecord;

- (int) tag;
- (void) setTag:(int) newTag;
@end