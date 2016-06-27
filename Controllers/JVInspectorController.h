#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol JVInspection;

@protocol JVInspector <NSObject>
- (NSView *) view;
- (NSSize) minSize;
- (NSString *) title;
- (NSString *) type;

@optional
- (void) willLoad;
- (void) didLoad;

- (BOOL) shouldUnload;
- (void) didUnload;
@end

@protocol JVInspection <NSObject>
- (id <JVInspector>) inspector;

@optional
- (void) willBeInspected;
@end

@protocol JVInspectionDelegator <NSObject>
- (nullable id <JVInspection>) objectToInspect;
- (IBAction) getInfo:(nullable id) sender;
@end

@interface JVInspectorController : NSWindowController <NSWindowDelegate> {
	id _self;
	BOOL _locked;
	id <JVInspection> _object;
	id <JVInspector> _inspector;
	BOOL _inspectorLoaded;
}
+ (JVInspectorController *) sharedInspector;
#if __has_feature(objc_class_property)
@property (readonly, strong, class) JVInspectorController *sharedInspector;
#endif
+ (void /*IBAction*/) showInspector:(id) sender; // only works because this is already wired up
- (IBAction) showInspector:(id) sender;
+ (JVInspectorController *) inspectorOfObject:(id <JVInspection>) object NS_RETURNS_NOT_RETAINED;

- (instancetype) initWithObject:(nullable id <JVInspection>) object lockedOn:(BOOL) locked;

- (IBAction) show:(nullable id) sender;
@property (readonly) BOOL locked;

- (void) inspectObject:(id <JVInspection>) object;

@property (readonly, strong) id<JVInspection> inspectedObject;
@property (readonly, strong) id<JVInspector> inspector;
@end

NS_ASSUME_NONNULL_END
