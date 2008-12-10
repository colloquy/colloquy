int main(int argc, char **argv) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	int result = UIApplicationMain(argc, argv, nil, @"CQColloquyApplication");
	[pool drain];
	return result;
}
