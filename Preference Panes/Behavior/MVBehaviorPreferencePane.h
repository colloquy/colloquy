#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>
#import <PreferencePanes/NSPreferencePane.h>

@interface MVBehaviorPreferencePane : NSPreferencePane {
	IBOutlet NSMatrix *pressReturn, *pressEnter, *closeWindow;
	IBOutlet NSButton *autoActions;
}
- (IBAction) pressReturnChoice:(id) sender;
- (IBAction) pressEnterChoice:(id) sender;
- (IBAction) closeWindowChoice:(id) sender;
- (IBAction) autoActionChoice:(id) sender;
@end
