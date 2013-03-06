@interface UIDevice (UIDeviceColloquyAdditions)
@property (nonatomic, readonly) NSString *modelIdentifier;

- (BOOL) isSystemSix;

- (BOOL) isPhoneModel;
- (BOOL) isPodModel;
- (BOOL) isPadModel;

- (BOOL) isRetina;
@end
