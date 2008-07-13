int main(int argc, char **argv) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	int result = UIApplicationMain(argc, argv, @"CQColloquyApplication", @"CQColloquyApplication");
	[pool drain];
	return result;
}
