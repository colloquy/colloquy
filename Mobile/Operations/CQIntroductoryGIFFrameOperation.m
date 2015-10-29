// This is not a full GIF parser. This does the minimum we can get away with to determine if something is an animated GIF or not.
// If we have an animated GIF, we get the first frame and rely on UIImage to construct the image for us. If we don't have an
// animated gif, we bail early, instead of attempting to render anything.
//
// Reference:
// http://www.w3.org/Graphics/GIF/spec-gif89a.txt
// http://en.wikipedia.org/wiki/Graphics_Interchange_Format#Example_GIF_file

#import "CQIntroductoryGIFFrameOperation.h"

typedef NS_ENUM(NSInteger, CQParseResult) {
	CQParseResultUnknown,
	CQParseResultNotAnimated,
	CQParseResultAnimated
};

enum {
	// Positions from the start of the GIF
	GIFHeaderStartPosition = 0x0,
	GIFHeaderEndPosition = 0x30D,
	GIFApplicationOrGraphicControlControlExtensionStartPosition = GIFHeaderEndPosition,
	GIFApplicationExtensionEndPosition = 0x320,
	GIFGraphicControlExtensionEndPosition = 0x315,

	// Positions from the start of a Graphic Control Extension block
	GIFGCEFrameDelayPosition = 0x4
};

static const char GIF89AMagicNumber[] = "GIF89a";
static const NSUInteger GIF89AMagicNumberLength = 6;

static const NSUInteger GIFExtensionBlockHeaderLength = 2;
static const char GIF89AApplicationExtensionBlockNumber[] = { 0x21, 0xFF };
static const char GIF89AGraphicControlExtensionBlockNumber[] = { 0x21, 0xF9 };
static const char GIF89AGraphicControlExtensionZeroDurationNumber[] = { 0x00, 0x00 };

static const NSUInteger GIF89AGCEFrameDelayHeaderLength = 2;

static const char GIF89AImageDescriptorNumber[] = { 0x2C };
static const NSUInteger GIF89AImageDescriptorLength = 1;

static const char GIF89AFileTerminatorNumber[] = { 0x3B };
static const NSUInteger GIF89AFileTerminatorLength = 1;

static const NSUInteger GIFCornerLength = 2;
static const NSUInteger GIFWidthLength = 2;
static const NSUInteger GIFHeightLength = 2;
static const NSUInteger GIFInterlacingLength = 1;
static const NSUInteger GIFMinimumLZWCodeSizeLength = 1;
static const NSUInteger GIFMinimumLZWCodeSizeBlockLengthIdentifierLength = 1;

#define maybeLog(args...) \
do { \
if (self.loggingEnabled) { \
NSLog(args); \
} \
} while(0)

NS_ASSUME_NONNULL_BEGIN

@implementation CQIntroductoryGIFFrameOperation {
	BOOL _cancelled;
	BOOL _started;
	BOOL _finished;

	NSURLConnection *_connection;
	NSMutableData *_data;

	uintptr_t _introductoryFrameImageDescriptorStartBlock;
	uintptr_t _introductoryFrameImageDescriptorEndBlock;
}

@synthesize introductoryFrameImage = _introductoryFrameImage;
@synthesize introductoryFrameImageData = _introductoryFrameImageData;

- (instancetype) init {
	NSAssert(NO, @"use [CQIntroductoryGIFFrameOperation initWithURL:] instead");
	return nil;
}

- (instancetype) initWithURL:(NSURL *) url {
	if (!(self = [super init]))
		return nil;

	_url = [url copy];

	return self;
}

#pragma mark -

- (BOOL) isCancelled {
	return _cancelled;
}

- (BOOL) isAsynchronous {
	return YES;
}

- (BOOL) isExecuting {
	return !_finished;
}

- (BOOL) isFinished {
	return _finished;
}

#pragma mark -

- (void) start {
	if (_started)
		return;

	[NSThread detachNewThreadSelector:@selector(main) toTarget:self withObject:nil];

	while (self.isExecuting)
		[[NSRunLoop currentRunLoop] runMode:NSRunLoopCommonModes beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
}

- (void) main {
	if (_started) {
		return;
	}

	_started = YES;

	[super main];

	if (_url.isFileURL) {
		_data = [NSMutableData dataWithContentsOfURL:_url];

		[self _downloadingAnimatedGIF];
		[self finish];
	} else {
		NSURLRequest *request = [NSURLRequest requestWithURL:_url];
		if (![NSURLConnection canHandleRequest:request]) {
			[self finish];
			return;
		}

		_connection = [NSURLConnection connectionWithRequest:request delegate:self];
		_data = [NSMutableData data];
	}
}

- (void) cancel {
	[self willChangeValueForKey:@"isCancelled"];
	_cancelled = YES;
	[self didChangeValueForKey:@"isCancelled"];

	[super cancel];

	[self finish];
}

- (void) finish {
	[self willChangeValueForKey:@"isFinished"];
	[self willChangeValueForKey:@"isExecuting"];
	_finished = YES;
	[self didChangeValueForKey:@"isFinished"];
	[self didChangeValueForKey:@"isExecuting"];

	[_connection cancel];

	__strong __typeof__((_target)) strongTarget = _target;
	if (_action) {
		[strongTarget performSelectorOnMainThread:_action withObject:self waitUntilDone:NO];
	}
}

#pragma mark -

- (void) connection:(NSURLConnection *) connection didReceiveData:(NSData *) data {
	[_data appendData:data];

	if (self._downloadingAnimatedGIF == CQParseResultNotAnimated) { // if we aren't downloading an animated gif, stop parsing
		[self cancel];
	} else if (self._canParseFirstFrame) { // if we can parse the first frame, we don't need to download anything else, exit
		[self finish];
	}
}

- (void) connectionDidFinishLoading:(NSURLConnection *) connection {
	[self finish];
}

- (void) connection:(NSURLConnection *) connection didFailWithError:(NSError *) error {
	[self finish];
}

#pragma mark -

- (CQParseResult) _downloadingAnimatedGIF {
	maybeLog(@"------ stage: %@", NSStringFromSelector(_cmd));

	// If we've saved the initial frame position, we already did the following checks and know that we have an animaged GIF
	if (_introductoryFrameImageDescriptorStartBlock) {
		maybeLog(@"image descriptor start block already found, we have an animated gif");
		return CQParseResultAnimated;
	}

	// If we don't have the magic number for the file, we don't know what kind of file we have to parse
	if (_data.length < GIF89AMagicNumberLength) {
		maybeLog(@"not enough bytes for a gif89a header to be detected (%tu, requiring 6), unknown if we have an animated gif", _data.length);
		return CQParseResultUnknown;
	}

	char *bytes = (char *)_data.bytes;

	// We must have a GIF89a image in order to have an animated gif.
	if (memcmp(GIF89AMagicNumber, bytes, GIF89AMagicNumberLength) != 0) {
		maybeLog(@"gif89a header not detected, we do not have an animated gif");
		return CQParseResultNotAnimated;
	}

	// If we don't know the next frame after the header, we're at an unknown parse state
	if (_data.length < (GIFApplicationOrGraphicControlControlExtensionStartPosition + GIFExtensionBlockHeaderLength)) {
		maybeLog(@"gif89a header not detected, unknown if we have an animated gif");
		return CQParseResultUnknown;
	}

	bytes += GIFApplicationOrGraphicControlControlExtensionStartPosition;

	// If we have an application extension block, skip past it. Nothing useful for us in there.
	if (memcmp(GIF89AApplicationExtensionBlockNumber, bytes, GIFExtensionBlockHeaderLength) == 0) {
		maybeLog(@"application extension block detected, skipping");
		bytes -= GIFApplicationOrGraphicControlControlExtensionStartPosition;
		bytes += GIFApplicationExtensionEndPosition;
	}

	// a graphic control extension is optional, but tells us transparency and colors
	if (memcmp(GIF89AGraphicControlExtensionBlockNumber, bytes, GIFExtensionBlockHeaderLength) != 0) {
		maybeLog(@"graphic control extension not detected, we do not have a translucent animated gif");
	}

	bytes += GIFGCEFrameDelayPosition;

	// If the frame duration is non-zero, we have another frame, an animated GIF!
	if (memcmp(GIF89AGraphicControlExtensionZeroDurationNumber, bytes, GIF89AGCEFrameDelayHeaderLength) != 0) {
		maybeLog(@"frame duration found");

		bytes += 4;

		// at least one image descriptor must be present, but, it might not be found here.
		if (memcmp(GIF89AImageDescriptorNumber, bytes, GIF89AImageDescriptorLength) != 0) {
			maybeLog(@"gif89a image descriptor not found after frame duration");

			bytes += GIF89AImageDescriptorLength;
		}

		_introductoryFrameImageDescriptorStartBlock = (uint32_t)(bytes - ((size_t)_data.bytes));

		maybeLog(@"image descriptor start block found, we have an animated gif");

		return CQParseResultAnimated;
	}

	maybeLog(@"all other checks failed, we do not have an animated gif");

	return CQParseResultNotAnimated;
}

- (BOOL) _canParseFirstFrame {
	maybeLog(@"------ %@", NSStringFromSelector(_cmd));

	if (_introductoryFrameImageDescriptorEndBlock) {
		maybeLog(@"image descriptor end block already found, we have an animated gif");
		return YES;
	}

	if (!self._downloadingAnimatedGIF) {
		return NO;
	}

	char *bytes = (char *)_data.bytes;
	NSUInteger bytesRemaining = _data.length;

#define checkAndAdvance(length) \
do { \
if (bytesRemaining < length) { \
return NO; \
} \
bytes += length; \
bytesRemaining -= length; \
} while (0)

	checkAndAdvance(_introductoryFrameImageDescriptorStartBlock);
	maybeLog(@"advanced data past image descriptor start block");

	checkAndAdvance(GIFCornerLength); // top/bottom corner
	maybeLog(@"advanced past image corner");

	checkAndAdvance(GIFCornerLength); // left/right corner
	maybeLog(@"advanced past image corner");

	checkAndAdvance(GIFWidthLength);
	maybeLog(@"advanced past image width");

	checkAndAdvance(GIFHeightLength);
	maybeLog(@"advanced past image height");

	checkAndAdvance(GIFInterlacingLength);
	maybeLog(@"advanced past interlacing");

	checkAndAdvance(GIFMinimumLZWCodeSizeLength);
	maybeLog(@"advanced past lzw code size");

	// Scan past chunks of lzw data; each chunk is prefixed with its length. length of 0 is the end of the frame.
	// each chunk will be a maximum of 255 bits.
	unsigned char *length;
	do {
		length = (unsigned char *)bytes;
		checkAndAdvance(GIFMinimumLZWCodeSizeBlockLengthIdentifierLength);
		maybeLog(@"advanced past lzw data length");

		checkAndAdvance(*length);
		maybeLog(@"advanced past lzw data");
	} while (*length);

#undef checkAndAdvance

	// At this point, we're at the end of the first frame and can render an image. Save the position we wound up at for later use.
	_introductoryFrameImageDescriptorEndBlock = (uintptr_t)(bytes - ((uintptr_t)_data.bytes));
	maybeLog(@"image descriptor end block found, we have an animated gif");

	return YES;
}

#pragma mark -

- (NSData *__nullable) introductoryFrameImageData {
	if (_cancelled) {
		maybeLog(@"operation canceled, not attempting to parse initial gif frame");
		return nil;
	}

	if (!self._canParseFirstFrame) {
		maybeLog(@"unable to parse first frame, not attempting to grab subdata");
		return nil;
	}

	if (self._downloadingAnimatedGIF != CQParseResultAnimated) {
		maybeLog(@"download state did not result in an animated gif");
		return nil;
	}

	if (_introductoryFrameImageData)
		return _introductoryFrameImageData;

	NSMutableData *data = [[_data subdataWithRange:NSMakeRange(0, _introductoryFrameImageDescriptorEndBlock)] mutableCopy];
	[data appendBytes:GIF89AFileTerminatorNumber length:GIF89AFileTerminatorLength]; // cut off any remaining data

	if (!data.length || data.length == GIF89AFileTerminatorLength) {
		maybeLog(@"no animated gif data found after subrange");
		return nil;
	}

	_introductoryFrameImageData = [data copy];

	return _introductoryFrameImageData;
}

#if TARGET_OS_IPHONE
- (UIImage *__nullable) introductoryFrameImage {
#else
	- (NSImage *__nullable) introductoryFrameImage {
#endif
		if (_introductoryFrameImage) {
			return _introductoryFrameImage;
		}

		NSData *data = self.introductoryFrameImageData;
		if (!data.length) {
			return nil;
		}

#if TARGET_OS_IPHONE
		_introductoryFrameImage = [[UIImage alloc] initWithData:self.introductoryFrameImageData];
#else
		_introductoryFrameImage = [[NSImage alloc] initWithData:self.introductoryFrameImageData];
#endif

		return _introductoryFrameImage;
	}
	@end
	
	NS_ASSUME_NONNULL_END
	
#undef maybeLog
