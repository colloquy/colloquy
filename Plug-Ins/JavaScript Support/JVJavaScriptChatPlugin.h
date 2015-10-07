#import "MVChatPluginManager.h"
#import "JVNotificationController.h"

#import <WebKit/WebKit.h>

extern NSString *JVJavaScriptErrorDomain;

@class WebScriptCallFrame;
@class WebView;

<<<<<<< HEAD
@interface JVJavaScriptChatPlugin : NSObject <MVChatPlugin, MVChatPluginNotificationSupport> {
=======
@interface JVJavaScriptChatPlugin : NSObject <MVChatPlugin, WebUIDelegate, WebPolicyDelegate, WebFrameLoadDelegate> {
>>>>>>> svn
	MVChatPluginManager *_manager;
	NSString *_path;
	NSDate *_modDate;
	WebView *_webview;
	NSString *_currentFunction;
	id _currentException;
	BOOL _loading;
	BOOL _errorShown;
	BOOL _scriptGlobalsAdded;
}
- (instancetype) initWithScriptAtPath:(NSString *) path withManager:(MVChatPluginManager *) manager;

@property (readonly, strong) MVChatPluginManager *pluginManager;
@property (readonly, copy) NSString *scriptFilePath;
- (void) reloadFromDisk;

- (void) setupScriptGlobalsForWebView:(WebView *) webView;
- (void) removeScriptGlobalsForWebView:(WebView *) webView;

- (void) reportErrorForCallFrame:(WebScriptCallFrame *) frame lineNumber:(unsigned int) line;
- (void) reportError:(NSDictionary *) error inFunction:(NSString *) functionName whileLoading:(BOOL) whileLoading;
- (id) callScriptFunctionNamed:(NSString *) functionName withArguments:(NSArray *) arguments forSelector:(SEL) selector;
@end
