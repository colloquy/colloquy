#import <Cocoa/Cocoa.h>

#import <MASPreferences.h>


@interface JVAppearancePreferencesViewController : NSViewController <MASPreferencesViewController>

- (void) selectStyleWithIdentifier:(NSString *) identifier;
- (void) selectEmoticonsWithIdentifier:(NSString *) identifier;

@end
