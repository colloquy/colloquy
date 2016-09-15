NS_ASSUME_NONNULL_BEGIN

@interface NSCharacterSet (Additions)
+ (NSCharacterSet *) illegalXMLCharacterSet;
+ (NSCharacterSet *) cq_encodedXMLCharacterSet;
#if __has_feature(objc_class_property)
@property (class, readonly, strong) NSCharacterSet *illegalXMLCharacterSet;
@property (class, readonly, strong, getter=cq_encodedXMLCharacterSet) NSCharacterSet *encodedXMLCharacterSet;
#endif
@end

NS_ASSUME_NONNULL_END
