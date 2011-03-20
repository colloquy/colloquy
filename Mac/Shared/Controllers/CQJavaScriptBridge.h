#import <JavaScriptCore/JavaScriptCore.h>

@interface CQJavaScriptObject : NSProxy {
@protected
	JSGlobalContextRef _context;
	JSObjectRef _object;
}
- (id) initWithScriptObject:(JSObjectRef) object andContext:(JSContextRef) context;

@property (readonly) JSGlobalContextRef context;
@property (readonly) JSObjectRef object;
@end

@interface CQJavaScriptBridge : NSObject
+ (JSValueRef) scriptValueForObject:(id) object usingContext:(JSContextRef) context;
+ (id) objectForScriptValue:(JSValueRef) value usingContext:(JSContextRef) context;

+ (void) addConstructorsInContext:(JSGlobalContextRef) context forClasses:(Class) firstClass, ... NS_REQUIRES_NIL_TERMINATION;
+ (void) addGlobalConstantInContext:(JSGlobalContextRef) context withName:(const char *) name andStringValue:(NSString *) value;
+ (void) addGlobalConstantInContext:(JSGlobalContextRef) context withName:(const char *) name andNumberValue:(NSInteger) value;
@end

#define CQJavaScriptBridgeAddGlobalNumberConstant(context, constant) [CQJavaScriptBridge addGlobalConstantInContext:context withName:#constant andNumberValue:constant]
#define CQJavaScriptBridgeAddGlobalStringConstant(context, constant) [CQJavaScriptBridge addGlobalConstantInContext:context withName:#constant andStringValue:constant]
