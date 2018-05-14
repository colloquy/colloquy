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
- (id <JVInspection>) objectToInspect;
- (IBAction) getInfo:(id) sender;
@end

COLLOQUY_EXPORT
@interface JVInspectorController : NSWindowController <NSWindowDelegate> {
	id _self;
	BOOL _locked;
	id <JVInspection> _object;
	id <JVInspector> _inspector;
	BOOL _inspectorLoaded;
}
+ (JVInspectorController *) sharedInspector;
+ (void /*IBAction*/) showInspector:(id) sender; // only works because this is already wired up
+ (JVInspectorController *) inspectorOfObject:(id <JVInspection>) object NS_RETURNS_NOT_RETAINED;

- (id) initWithObject:(id <JVInspection>) object lockedOn:(BOOL) locked;

- (IBAction) show:(id) sender;
- (BOOL) locked;

- (void) inspectObject:(id <JVInspection>) object;

- (id <JVInspection>) inspectedObject;
- (id <JVInspector>) inspector;
@end
