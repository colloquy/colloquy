NS_ASSUME_NONNULL_BEGIN

@interface UIDevice (UIDeviceColloquyAdditions)
@property (nonatomic, readonly) NSString *modelIdentifier;

@property (getter=isPadModel, readonly) BOOL padModel;

@property (getter=isRetina, readonly) BOOL retina;
@end

NS_ASSUME_NONNULL_END
