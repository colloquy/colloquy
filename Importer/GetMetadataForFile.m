#include <CoreServices/CoreServices.h>
#import <Foundation/Foundation.h>
#include <libxml/tree.h>
#include <libxml/xmlerror.h>
#include "GetMetadataForFile.h"

/* Sample transcript:
<log began="2005-07-11 12:19:09 -0400" source="irc://irc.freenode.net/%23barcamp">
 <event id="H5OI9GYEXB" name="memberJoined" occurred="2005-08-20 22:13:28 -0400">
  <message><span class="member">vdwal</span> joined the chat room.</message>
  <who hostmask="n=vanderwa@dsl092-170-254.wdc2.dsl.speakeasy.net">vdwal</who>
 </event>
 <envelope>
  <sender hostmask="i=urgy@c-67-188-71-51.hsd1.ca.comcast.net">urgen</sender>
  <message id="H7DJHOYEXB" received="2005-08-20 22:13:36 -0400">hi</message>
 </envelope>
 <envelope>
  <sender hostmask="n=vanderwa@dsl092-170-254.wdc2.dsl.speakeasy.net">vdwal</sender>
  <message id="XVQ44ZYEXB" received="2005-08-20 22:13:47 -0400">where did everybody go?</message>
  <message id="GD3YCAZEXB" received="2005-08-20 22:13:58 -0400">hi</message>
  <message id="D0TAANZEXB" received="2005-08-20 22:14:11 -0400">i lost my nickname and my legs</message>
  <message id="H5CJHSZEXB" received="2005-08-20 22:14:16 -0400">stuck again</message>
 </envelope>
</log>
*/

__private_extern @interface JVChatTranscriptMetadataExtractor : NSObject <NSXMLParserDelegate> {
	BOOL inEnvelope;
	BOOL inMessage;
	NSString *lastElement;
	NSDate *dateStarted;
	NSString *lastEventDate;
	NSString *source;
}
@property (strong) NSCharacterSet *lineBreaks;
@property (strong) NSMutableString *content;
@property (strong) NSMutableSet *participants;

- (instancetype) initWithCapacity:(NSUInteger) capacity NS_DESIGNATED_INITIALIZER;
@property (readonly, copy) NSDictionary *metadataAttributes;
@end

@implementation JVChatTranscriptMetadataExtractor
@synthesize lineBreaks;
@synthesize content;
@synthesize participants;

- (instancetype)init
{
	return self = [self initWithCapacity:40];
}

- (instancetype)initWithCapacity:(NSUInteger)capacity {
	if (self = [super init]) {
		self.content = [[NSMutableString alloc] initWithCapacity:capacity];
		self.participants = [[NSMutableSet alloc] initWithCapacity:400];
		self.lineBreaks = [NSCharacterSet characterSetWithCharactersInString:@"\n\r"];
	}

	return self;
}

- (NSDictionary *)metadataAttributes {
	NSMutableDictionary *ret = [[NSMutableDictionary alloc] init];
	ret[(NSString *) kMDItemTextContent] = content;

	if (dateStarted)
		ret[(NSString *) kMDItemContentCreationDate] = dateStarted;
	if ([lastEventDate length]) {
		NSDate *lastDate = [NSDate dateWithString:lastEventDate];
		if( lastDate ) {
			ret[(NSString *) kMDItemContentModificationDate] = lastDate;
			ret[(NSString *) kMDItemLastUsedDate] = lastDate;

			if( dateStarted ) {
				// Set Duration
				NSTimeInterval logDuration = [lastDate timeIntervalSinceDate:dateStarted];
				ret[(NSString *) kMDItemDurationSeconds] = @(logDuration);

				// Set Coverage
				NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
				[formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
				[formatter setDateStyle:NSDateFormatterShortStyle];
				[formatter setTimeStyle:NSDateFormatterShortStyle];

				NSString *coverageWording = [[NSString alloc] initWithFormat:@"%@ - %@", [formatter stringFromDate:dateStarted], [formatter stringFromDate:lastDate]];
				ret[(NSString *) kMDItemCoverage] = coverageWording;
			}
		}
	}

	if ([participants count])
		ret[(NSString *) kMDItemContributors] = [participants allObjects];
	if ([source length])
		ret[(NSString *) kMDItemWhereFroms] = @[source];

	ret[(NSString *) kMDItemKind] = @"transcript";
	ret[(NSString *) kMDItemCreator] = @"Colloquy";

	return [ret copy];
}

- (void) parser:(NSXMLParser *) parser didStartElement:(NSString *) elementName namespaceURI:(NSString *) namespaceURI qualifiedName:(NSString *) qName attributes:(NSDictionary *) attributes {
	lastElement = elementName;

	if ([elementName isEqualToString:@"envelope"]) {
		inEnvelope = YES;
	} else if (inEnvelope && [elementName isEqualToString:@"message"]) {
		inMessage = YES;
		NSString *date = attributes[@"received"];
		if (date) {
			lastEventDate = date;
			if (!dateStarted)
				dateStarted = [[NSDate alloc] initWithString:date];
		}
	} else if (!inEnvelope && [elementName isEqualToString:@"event"] ) {
		NSString *date = attributes[@"occurred"];
		if (date) {
			lastEventDate = date ;
			if (!dateStarted)
				dateStarted = [[NSDate alloc] initWithString:date];
		}
	} else if (!inEnvelope && [elementName isEqualToString:@"log"]) {
		NSString *date = attributes[@"began"];
		if (date && !dateStarted)
			dateStarted = [[NSDate alloc] initWithString:date];
		if (!source)
			source = attributes[@"source"];
	}
}

- (void) parser:(NSXMLParser *) parser didEndElement:(NSString *) elementName namespaceURI:(NSString *) namespaceURI qualifiedName:(NSString *) qName {
	if (inEnvelope && [elementName isEqualToString:@"envelope"]) {
		inEnvelope = NO;
	} else if (inEnvelope && inMessage && [elementName isEqualToString:@"message"] ) {
		inMessage = NO;
		[content appendString:@"\n"]; // append a newline after messages
	}

	lastElement = nil;
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
	if (inEnvelope && inMessage) {
		NSString *newString = [string stringByTrimmingCharactersInSet:lineBreaks];
		if ([newString length])
			[content appendString:newString];
	} else if (inEnvelope && [lastElement isEqualToString:@"sender"]) {
		if ([string length])
			[participants addObject:string];
	}
}

@end

static BOOL GetMetadataForNSURL(void* thisInterface, NSMutableDictionary *attributes, NSString *contentTypeUTI, NSURL *urlForFile)
{
	NSXMLParser *parser;
	JVChatTranscriptMetadataExtractor *extractor;
	NSNumber *fileSizeClass;
	
	if (![urlForFile checkResourceIsReachableAndReturnError:NULL])
		goto badend;
	
	parser = [[NSXMLParser alloc] initWithContentsOfURL:urlForFile];
	
	if (![urlForFile getResourceValue:&fileSizeClass forKey:NSURLFileSizeKey error:NULL])
		goto badend;
	
	unsigned long long fileSize = [fileSizeClass unsignedLongLongValue];
	fileSizeClass = nil;
	NSUInteger capacity = (NSUInteger)( fileSize ? fileSize / 3 : 5000 ); // the message content takes up about a third of the XML file's size
	
	extractor = [[JVChatTranscriptMetadataExtractor alloc] initWithCapacity:capacity];
	
	[parser setDelegate:extractor];
	[parser parse];
	
	[attributes addEntriesFromDictionary:[extractor metadataAttributes]];
	
    parser = nil;
	xmlSetStructuredErrorFunc( NULL, NULL );
	return YES;
	
badend:
	return NO;
}


Boolean GetMetadataForURL(void* thisInterface, CFMutableDictionaryRef attributes, CFStringRef contentTypeUTI, CFURLRef urlForFile)
{
	@autoreleasepool {
		return GetMetadataForNSURL(thisInterface, (__bridge NSMutableDictionary*)attributes, (__bridge NSString*)contentTypeUTI, (__bridge NSURL*)urlForFile);
	}
}

Boolean GetMetadataForFile(void *thisInterface, CFMutableDictionaryRef attributes, CFStringRef contentTypeUTI, CFStringRef pathToFile) {
	@autoreleasepool {
		return GetMetadataForNSURL(thisInterface, (__bridge NSMutableDictionary*)attributes, (__bridge NSString*)contentTypeUTI, [NSURL fileURLWithPath:(__bridge NSString*)pathToFile]);
	}
}
