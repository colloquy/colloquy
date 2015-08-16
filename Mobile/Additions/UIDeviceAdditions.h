@interface UIDevice (UIDeviceColloquyAdditions)
@property (nonatomic, readonly) NSString *modelIdentifier;

@property (getter=isRunningOS9, readonly) BOOL runningOS9;
@property (getter=isPadModel, readonly) BOOL padModel;
@property (getter=isPhoneModel, readonly) BOOL phoneModel;

@property (getter=isRetina, readonly) BOOL retina;
@end
