#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>

@class NSString;
@class NSTextView;
@class NSTextField;
@class NSWindow;

@interface MVCrashCatcher : NSObject {
	NSString *programName, *logPath;
	IBOutlet NSTextView *comments, *log;
	IBOutlet NSTextField *description;
	IBOutlet NSWindow *window;
	BOOL crashLogExists;
}
+ (void) check;

- (id) init;
- (void) dealloc;

- (IBAction) sendCrashLog:(id) sender;
- (IBAction) dontSend:(id) sender;
@end
