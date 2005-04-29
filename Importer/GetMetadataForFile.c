#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h> 
#include <Foundation/Foundation.h>

/* -----------------------------------------------------------------------------
   Step 1
   Set the UTI types the importer supports
  
   Modify the CFBundleDocumentTypes entry in Info.plist to contain
   an array of Uniform Type Identifiers (UTI) for the LSItemContentTypes 
   that your importer can handle
  
   ----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
   Step 2 
   Implement the GetMetadataForFile function
  
   Implement the GetMetadataForFile function below to scrape the relevant
   metadata from your document and return it as a CFDictionary using standard keys
   (defined in MDItem.h) whenever possible.
   ----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
   Step 3 (optional) 
   If you have defined new attributes, update the schema.xml file
  
   Edit the schema.xml file to include the metadata keys that your importer returns.
   Add them to the <allattrs> and <displayattrs> elements.
  
   Add any custom types that your importer requires to the <attributes> element
  
   <attribute name="com_mycompany_metadatakey" type="CFString" multivalued="true"/>
  
   ----------------------------------------------------------------------------- */



/* -----------------------------------------------------------------------------
    Get metadata attributes from file
   
   This function's job is to extract useful information your file format supports
   and return it as a dictionary
   ----------------------------------------------------------------------------- */

Boolean GetMetadataForFile(void* thisInterface, 
			   CFMutableDictionaryRef attributes, 
			   CFStringRef contentTypeUTI,
			   CFStringRef pathToFile) {
    /* Pull any available metadata from the file at the specified path */
    /* Return the attribute keys and attribute values in the dict */
    /* Return TRUE if successful, FALSE if there was no data provided */
	NSMutableDictionary *returnDict = (NSMutableDictionary *)attributes;
	NSError *error;
	NSMutableArray *participants = [[NSMutableArray alloc] init];
    NSXMLDocument *transcriptDOM = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:(NSString *)pathToFile] 
																		options:NSXMLDocumentTidyXML
																		  error:&error];
	
	// Get date started
	NSArray *dateArray = [transcriptDOM nodesForXPath:@"/log[1]/@began" error:&error];
    NSDate *dateStarted = [NSDate dateWithString:[[dateArray objectAtIndex:0] stringValue]];
	[returnDict setObject:dateStarted forKey:(NSString *)kMDItemContentCreationDate];
	
	// Get date of last message
	NSArray *xpathResult = [transcriptDOM nodesForXPath:@"/log[1]/envelope[last()]/message[last()]/@received" error:&error];
	NSDate *lastMessageDate = [NSDate dateWithString:[[xpathResult objectAtIndex:0] stringValue]];
	NSTimeInterval logDuration = [lastMessageDate timeIntervalSinceDate:dateStarted];
	
	// Set Duration
	[returnDict setObject:[NSNumber numberWithInt:logDuration] forKey:(NSString *)kMDItemDurationSeconds];
	
	// Get WhereFroms
	xpathResult = [transcriptDOM nodesForXPath:@"/log[1]@source" error:&error];
	NSString *fromURL = nil;
	if ( [xpathResult count] ) {
		fromURL = [[xpathResult objectAtIndex:0] stringValue];
		[returnDict setObject:fromURL forKey:(NSString *)kMDItemWhereFroms];
	}
	
	// Set Title and Coverage
	NSDateFormatter *formatter = [[NSDateFormatter alloc] initWithDateFormat:@"%A, the %d of %B at %I:%M" allowNaturalLanguage:NO];
	NSString *coverageWording = nil;
	
	// Set Coverage
	if ( fromURL ) {
		coverageWording = [NSString stringWithFormat:@"Conversation from %@ to %@ in %@", [formatter stringFromDate:dateStarted],
																							[formatter stringFromDate:lastMessageDate],
																							fromURL];
	} else {
		coverageWording = [NSString stringWithFormat:@"Conversation from %@ to %@", [formatter stringFromDate:dateStarted],
																					[formatter stringFromDate:lastMessageDate]];
	}
	[returnDict setObject:coverageWording forKey:(NSString *)kMDItemCoverage];
	[returnDict setObject:coverageWording forKey:(NSString *)kMDItemTitle];
	
	// Get Participants
	NSArray *participantsArray = [transcriptDOM nodesForXPath:@"/log[1]/envelope/sender" error:&error];
	NSEnumerator *pEnum = [participantsArray objectEnumerator];
	NSXMLNode *participantName = nil;
	
	while ( participantName = [pEnum nextObject] ) {
		NSString *userNick = [participantName stringValue];
		
		if ( ! [participants containsObject:userNick] )
			[participants addObject:[participantName stringValue]];
	}
	[returnDict setObject:participants forKey:(NSString *)kMDItemContributors];
	
	// Now the stuff that doesn't change
	[returnDict setObject:[NSArray arrayWithObject:@"Colloquy"] forKey:(NSString *)kMDItemEncodingApplications];
	

    return TRUE;
}
