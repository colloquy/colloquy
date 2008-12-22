#import <Foundation/NSDictionary.h>

@interface NSDictionary (NSDictionaryAdditions)
+ (id) dictionaryWithKeys:(id *) keys fromDictionary:(NSDictionary *) dictionary;
- (id) initWithKeys:(id *) keys fromDictionary:(NSDictionary *) dictionary;
@end
