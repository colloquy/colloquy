@interface UIDevice (UIDeviceColloquyAdditions)
@property (nonatomic, readonly) NSString *modelIdentifier;

- (BOOL) isSystemSeven;

- (BOOL) isPhoneModel;
- (BOOL) isPodModel;
- (BOOL) isPadModel;

- (BOOL) isRetina;
@end
