@interface UIDevice (UIDeviceColloquyAdditions)
@property (nonatomic, readonly) NSString *modelIdentifier;

- (BOOL) isSystemFour;
- (BOOL) isSystemFive;

- (BOOL) isPhoneModel;
- (BOOL) isPodModel;
- (BOOL) isPadModel;
@end
