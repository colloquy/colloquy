@interface UIDevice (UIDeviceColloquyAdditions)
#if TARGET_IPHONE_SIMULATOR
@property (nonatomic, readonly, retain) NSString *model;
#endif

- (BOOL) isPhoneModel;
- (BOOL) isPodModel;
- (BOOL) isPadModel;
@end
