#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>

@class NSDictionary;
@class NSTextView;
@class NSTextField;
@class NSWindow;

@interface MVSoftwareUpdate : NSObject {
	IBOutlet NSTextView *about;
	IBOutlet NSTextField *program, *version;
	IBOutlet NSWindow *window;
	NSDictionary *updateInfo;
}
+ (void) checkAutomatically:(BOOL) flag;

- (IBAction) download:(id) sender;
- (IBAction) dontDownload:(id) sender;
@end
