NS_ASSUME_NONNULL_BEGIN

@interface UIDevice (UIDeviceColloquyAdditions)
@property (nonatomic, readonly) NSString *modelIdentifier;

@property (getter=isPadModel, readonly) BOOL padModel;
@end

NS_ASSUME_NONNULL_END
