int main(int argc, const char *argv[]) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	// Start main controller here.

	[pool drain];

	NSRunLoop *runloop = [NSRunLoop mainRunLoop];
	while ([runloop runMode:NSRunLoopCommonModes beforeDate:[NSDate distantFuture]]);

	return 0;
}
