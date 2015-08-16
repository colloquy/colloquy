@interface UIDevice (UIDeviceColloquyAdditions)
@property (nonatomic, readonly) NSString *modelIdentifier;

@property (getter=isSystemEight, readonly) BOOL systemEight;
@property (getter=isSystemNine, readonly) BOOL systemNine;

@property (getter=isPhoneModel, readonly) BOOL phoneModel;
@property (getter=isPadModel, readonly) BOOL padModel;

@property (getter=isRetina, readonly) BOOL retina;
@end
