@interface UIDevice (UIDeviceColloquyAdditions)
@property (nonatomic, readonly) NSString *modelIdentifier;

- (BOOL) isPhoneModel;
- (BOOL) isPadModel;

- (BOOL) isRetina;
@end
