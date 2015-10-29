NS_ASSUME_NONNULL_BEGIN

@interface NSDictionary (NSDictionaryAdditions)
+ (NSDictionary *) dictionaryWithKeys:(NSArray <id <NSCopying>> *) keys fromDictionary:(NSDictionary *) dictionary;

@property (readonly, copy) NSData *postDataRepresentation; // doesn't support form data
@end

@interface NSMutableDictionary (NSDictionaryAdditions)
- (instancetype) initWithKeys:(NSArray <id <NSCopying>> *) keys fromDictionary:(NSDictionary *) dictionary;
- (void) setObjectsForKeys:(NSArray <id <NSCopying>> *) keys fromDictionary:(NSDictionary *) dictionary;;
@end

NS_ASSUME_NONNULL_END
