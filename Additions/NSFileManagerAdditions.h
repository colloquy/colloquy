typedef struct {
	BOOL x86;
	BOOL x86_64;
	BOOL ppc32;
	BOOL ppc64;
	BOOL arm;
	NSInteger unknown; // 68k, MIPS, etc
} MVArchitectures;

@interface NSFileManager (Additions)
- (MVArchitectures) architecturesForBinaryAtPath:(NSString *) path;

- (BOOL) canExecutePluginAtPath:(NSString *) pluginPath;
@end

NSString *NSStringFromMVArchitectures(MVArchitectures architectures);
