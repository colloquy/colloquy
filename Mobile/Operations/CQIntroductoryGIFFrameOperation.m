// This is not a full GIF parser. This does the bare minimum we can get away with to determine if something is an animated GIF or not.
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

- (instancetype) initWithURL:(NSURL *) url {
	NSParameterAssert(url);

	if (!(self = [super init]))
		return nil;

	_url = [url copy];

	return self;
}

#pragma mark -

- (BOOL) isCancelled {
	return _cancelled;
}

- (BOOL) isConcurrent {
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

	[self main];
}

- (void) main {
	if (_started)
		return;

	_started = YES;

	[super main];

	if (_url.isFileURL) {
		_data = [[NSData dataWithContentsOfURL:_url] mutableCopy];

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

		while (!_finished)
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.25]];
	}
}

- (void) cancel {
	[self willChangeValueForKey:@"isCancelled"];
	_cancelled = YES;
	[self didChangeValueForKey:@"isCancelled"];

	[super cancel];

	[_connection cancel];

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
	if (_action)
		[strongTarget performSelectorOnMainThread:_action withObject:self waitUntilDone:NO];
}

#pragma mark -

- (void) connection:(NSURLConnection *) connection didReceiveData:(NSData *) data {
	[_data appendData:data];

	if (self._downloadingAnimatedGIF == CQParseResultNotAnimated) // if we aren't downloading an animated gif, stop parsing
		[self cancel];
	else if (self._canParseFirstFrame) // if we can parse the first frame, we don't need to download anything else, exit
		[self finish];
}

- (void) connectionDidFinishLoading:(NSURLConnection *) connection {
	[self finish];
}

- (void) connection:(NSURLConnection *) connection didFailWithError:(NSError *) error {
	[self finish];
}

#pragma mark -

- (CQParseResult) _downloadingAnimatedGIF {
	// If we've saved the initial frame position, we already did the following checks and know that we have an animaged GIF
	if (_introductoryFrameImageDescriptorStartBlock)
		return CQParseResultAnimated;

	// If we don't have the magic number for the file, we don't know what kind of file we have to parse
	if (_data.length < 6)
		return CQParseResultUnknown;

	char *bytes = (char *)_data.bytes;

	// We must have a GIF89a image in order to have an animated gif.
	if (memcmp(GIF89AMagicNumber, bytes, GIF89AMagicNumberLength) != 0)
		return CQParseResultNotAnimated;

	// If we don't know the next frame after the header, we're at an unknown parse state
	if (_data.length < (GIFApplicationOrGraphicControlControlExtensionStartPosition + GIFExtensionBlockHeaderLength))
		return CQParseResultUnknown;

	bytes += GIFApplicationOrGraphicControlControlExtensionStartPosition;

	// If we have an application extension block, skip past it. Nothing useful for us in there.
	if (memcmp(GIF89AApplicationExtensionBlockNumber, bytes, GIFExtensionBlockHeaderLength) == 0) {
		bytes -= GIFApplicationOrGraphicControlControlExtensionStartPosition;
		bytes += GIFApplicationExtensionEndPosition;
	}

	// If we don't have a graphic control extension block at this point, give up.
	if (memcmp(GIF89AGraphicControlExtensionBlockNumber, bytes, GIFExtensionBlockHeaderLength) != 0)
		return CQParseResultNotAnimated;

	bytes += GIFGCEFrameDelayPosition;

	// If the frame duration is non-zero, we have another frame, an animated GIF!
	if (memcmp(GIF89AGraphicControlExtensionZeroDurationNumber, bytes, GIF89AGCEFrameDelayHeaderLength) != 0) {
		bytes += 4;

		if (memcmp(GIF89AImageDescriptorNumber, bytes, GIF89AImageDescriptorLength) != 0)
			return CQParseResultNotAnimated;

		bytes += GIF89AImageDescriptorLength;

		_introductoryFrameImageDescriptorStartBlock = (uint32_t)(bytes - ((size_t)_data.bytes));

		return CQParseResultAnimated;
	}

	return CQParseResultNotAnimated;
}

- (BOOL) _canParseFirstFrame {
	if (_introductoryFrameImageDescriptorEndBlock)
		return YES;

	if (!self._downloadingAnimatedGIF)
		return NO;

	char *bytes = (char *)_data.bytes;
	NSUInteger bytesRemaining = _data.length;

#define checkAndAdvance(length) \
	do { \
		if (bytesRemaining < length) \
			return NO; \
		bytes += length; \
		bytesRemaining -= length; \
	} while (0)

	checkAndAdvance(_introductoryFrameImageDescriptorStartBlock);
	checkAndAdvance(GIFCornerLength); // top/bottom corner
	checkAndAdvance(GIFCornerLength); // left/right corner
	checkAndAdvance(GIFWidthLength);
	checkAndAdvance(GIFHeightLength);
	checkAndAdvance(GIFInterlacingLength);
	checkAndAdvance(GIFMinimumLZWCodeSizeLength);

	// Scan past chunks of lzw data; each chunk is prefixed with its length. length of 0 is the end of the frame.
	// each chunk will be a maximum of 255 bits.
	unsigned char *length;
	do {
		length = (unsigned char *)bytes;
		checkAndAdvance(GIFMinimumLZWCodeSizeBlockLengthIdentifierLength);
		checkAndAdvance(*length);
	} while (*length);

#undef checkAndAdvance

	// At this point, we're at the end of the first frame and can render an image. Save the position we wound up at for later use.
	_introductoryFrameImageDescriptorEndBlock = (uintptr_t)(bytes - ((uintptr_t)_data.bytes));

	return YES;
}

#pragma mark -

- (NSData *) introductoryFrameImageData {
	if (_cancelled || !self._canParseFirstFrame || self._downloadingAnimatedGIF != CQParseResultAnimated)
		return nil;

	if (_introductoryFrameImageData)
		return _introductoryFrameImageData;

	NSMutableData *data = [[_data subdataWithRange:NSMakeRange(0, _introductoryFrameImageDescriptorEndBlock)] mutableCopy];
	[data appendBytes:GIF89AFileTerminatorNumber length:GIF89AFileTerminatorLength]; // cut off any remaining data

	if (!data.length)
		return nil;

	_introductoryFrameImageData = [data copy];

	return _introductoryFrameImageData;
}

#if TARGET_OS_IPHONE
- (UIImage *) introductoryFrameImage {
#else
- (NSImage *) introductoryFrameImage {
#endif
	if (_introductoryFrameImage)
		return _introductoryFrameImage;

	NSData *data = self.introductoryFrameImageData;
	if (!data.length)
		return nil;

#if TARGET_OS_IPHONE
	_introductoryFrameImage = [[UIImage alloc] initWithData:self.introductoryFrameImageData];
#else
	_introductoryFrameImage = [[NSImage alloc] initWithData:self.introductoryFrameImageData];
#endif

	return _introductoryFrameImage;
}
@end
