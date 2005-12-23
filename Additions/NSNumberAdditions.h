@interface NSNumber (NSNumberAdditions)
+ (NSNumber *) numberWithBytes:(const void *) bytes objCType:(const char *) type;
@end