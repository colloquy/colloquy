@interface UIDevice (UIDeviceColloquyAdditions)
@property (nonatomic, readonly) NSString *modelIdentifier;

- (BOOL) isSystemSeven;
- (BOOL) isSystemSevenOne;

- (BOOL) isPhoneModel;
- (BOOL) isPodModel;
- (BOOL) isPadModel;

- (BOOL) isRetina;
@end
