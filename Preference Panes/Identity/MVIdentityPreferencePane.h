#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>
#import <PreferencePanes/NSPreferencePane.h>

@interface MVIdentityPreferencePane : NSPreferencePane {
	IBOutlet NSTextField *realName;
	IBOutlet NSTextView *information;
}
@end
