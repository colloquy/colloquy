#import "MVChatPluginManager.h"

extern NSString *JVJavaScriptErrorDomain;

@class WebView;

@interface JVJavaScriptChatPlugin : NSObject <MVChatPlugin> {
	MVChatPluginManager *_manager;
	NSString *_path;
	NSDate *_modDate;
	NSString *_uniqueModuleName;
	WebView *_webview;
}
- (id) initWithScriptAtPath:(NSString *) path withManager:(MVChatPluginManager *) manager;

- (MVChatPluginManager *) pluginManager;
- (NSString *) scriptFilePath;
- (void) reloadFromDisk;

- (void) setupScriptGlobalsForWebView:(WebView *) webView;

- (id) callScriptFunctionNamed:(NSString *) functionName withArguments:(NSArray *) arguments forSelector:(SEL) selector;
@end
