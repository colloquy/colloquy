#import "NSUserDefaultsAdditions.h"

@implementation NSUserDefaults (Additions)
- (BOOL) removeKey:(NSString *) key fromSettingsPlist:(NSString *) plist {
	NSString *plistPath = [NSString stringWithFormat:@"%@/Settings.bundle/%@.plist", [[NSBundle mainBundle] bundlePath], plist];
	NSMutableDictionary *plistDictionary = [NSMutableDictionary dictionaryWithContentsOfFile:plistPath];
	NSMutableArray *preferencesArray = [plistDictionary objectForKey:@"PreferencesSpecifier"];

	for (NSUInteger i = 0; i < preferencesArray.count; i++) {
		NSDictionary *preference = [preferencesArray objectAtIndex:i];
		if ([[preference objectForKey:@"key"] isEqualToString:key]) {
			[preferencesArray removeObjectAtIndex:i];
			[plistDictionary setObject:preferencesArray forKey:@"PreferencesSpecifier"];

			return [plistDictionary writeToFile:plistPath atomically:NO];
		}
	}

	return NO;
}
@end
