

@interface MVCrashCatcher : NSObject {
	IBOutlet NSTextView *comments;
	IBOutlet NSTextView *log;
	IBOutlet NSTextField *description;
	IBOutlet NSWindow *window;
	NSString *logPath;
	NSURLConnection *urlConnection;
}
+ (void) check;

- (IBAction) sendCrashLog:(id) sender;
- (IBAction) dontSend:(id) sender;
@end
