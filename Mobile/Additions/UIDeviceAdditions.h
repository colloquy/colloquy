@interface UIDevice (UIDeviceColloquyAdditions)
@property (nonatomic, readonly) NSString *modelIdentifier;

- (BOOL) isSystemEight;

- (BOOL) isPhoneModel;
- (BOOL) isPadModel;

- (BOOL) isRetina;
@end
