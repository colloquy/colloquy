#import "JVPreferencesController.h"
#import <Foundation/Foundation.h>

@implementation JVPreferencesController
- (id) init {
	_preferenceTitles = [[NSMutableArray array] retain];
	_preferenceModules = [[NSMutableArray array] retain];
	return self;
}

- (BOOL) usesButtons {
	return NO;
}
@end
