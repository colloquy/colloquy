@interface UIDevice (UIDeviceColloquyAdditions)
@property (nonatomic, readonly) NSString *modelIdentifier;

- (BOOL) isSystemFour;

- (BOOL) isPhoneModel;
- (BOOL) isPodModel;
- (BOOL) isPadModel;
@end
