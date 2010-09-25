@implementation NSFileManager (Additions)
- (NSString *) localDocumentsDirectoryPath {
	return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}
@end
