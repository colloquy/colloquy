@interface CQKeychain : NSObject
+ (CQKeychain *) standardKeychain;

- (void) setPassword:(NSString *) password forServer:(NSString *) server account:(NSString *) account;
- (NSString *) passwordForServer:(NSString *) server account:(NSString *) account;
- (void) removePasswordForServer:(NSString *) server account:(NSString *) account;
@end
