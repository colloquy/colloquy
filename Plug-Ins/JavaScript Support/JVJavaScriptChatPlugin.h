#import "MVChatPluginManager.h"

extern NSString *JVJavaScriptErrorDomain;

@class WebScriptCallFrame;
@class WebView;

@interface JVJavaScriptChatPlugin : NSObject <MVChatPlugin> {
	MVChatPluginManager *_manager;
	NSString *_path;
	NSDate *_modDate;
	WebView *_webview;
	NSString *_currentFunction;
	id _currentException;
	BOOL _loading;
	BOOL _errorShown;
}
- (id) initWithScriptAtPath:(NSString *) path withManager:(MVChatPluginManager *) manager;

- (MVChatPluginManager *) pluginManager;
- (NSString *) scriptFilePath;
- (void) reloadFromDisk;

- (void) setupScriptGlobalsForWebView:(WebView *) webView;

- (void) reportErrorForCallFrame:(WebScriptCallFrame *) frame lineNumber:(unsigned int) line;
- (void) reportError:(NSDictionary *) error inFunction:(NSString *) functionName whileLoading:(BOOL) whileLoading;
- (id) callScriptFunctionNamed:(NSString *) functionName withArguments:(NSArray *) arguments forSelector:(SEL) selector;
@end
