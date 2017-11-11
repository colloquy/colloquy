#import <Cocoa/Cocoa.h>

#import <MASPreferences/MASPreferences.h>


@interface JVAppearancePreferencesViewController : NSViewController <MASPreferencesViewController>

- (void) selectStyleWithIdentifier:(NSString *) identifier;
- (void) selectEmoticonsWithIdentifier:(NSString *) identifier;

@end
