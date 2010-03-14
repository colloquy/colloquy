@interface CQKeychain : NSObject
+ (CQKeychain *) standardKeychain;

- (void) setPassword:(NSString *) password forArea:(NSString *) area account:(NSString *) account;
- (NSString *) passwordForArea:(NSString *) area account:(NSString *) account;
- (void) removePasswordForArea:(NSString *) area account:(NSString *) account;
@end
