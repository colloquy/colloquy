#import "MVChatPluginManager.h"

extern NSString *JVJavaScriptErrorDomain;

@class WebView;

@interface JVJavaScriptChatPlugin : NSObject <MVChatPlugin> {
	MVChatPluginManager *_manager;
	NSString *_path;
	NSDate *_modDate;
	WebView *_webview;
	NSString *_currentFunction;
	BOOL _loading;
}
- (id) initWithScriptAtPath:(NSString *) path withManager:(MVChatPluginManager *) manager;

- (MVChatPluginManager *) pluginManager;
- (NSString *) scriptFilePath;
- (void) reloadFromDisk;

- (void) setupScriptGlobalsForWebView:(WebView *) webView;

- (void) reportError:(NSDictionary *) error inFunction:(NSString *) functionName whileLoading:(BOOL) whileLoading;
- (id) callScriptFunctionNamed:(NSString *) functionName withArguments:(NSArray *) arguments forSelector:(SEL) selector;
@end
