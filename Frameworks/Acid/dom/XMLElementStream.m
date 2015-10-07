//============================================================================
// 
//     License:
// 
//     This library is free software; you can redistribute it and/or
//     modify it under the terms of the GNU Lesser General Public
//     License as published by the Free Software Foundation; either
//     version 2.1 of the License, or (at your option) any later version.
// 
//     This library is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//     Lesser General Public License for more details.
// 
//     You should have received a copy of the GNU Lesser General Public
//     License along with this library; if not, write to the Free Software
//     Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  
//     USA
// 
//     Copyright (C) 2002-2003 Dave Smith (dizzyd@jabber.org)
// 
// $Id: XMLElementStream.m,v 1.1 2004/07/19 03:49:03 jtownsend Exp $
//============================================================================

#import "acid-dom.h"
#import <objc/objc-runtime.h>
#import <expat.h>

@interface NSObject (private)
+(instancetype) constructElement:(XMLQName*)qname withAttributes:(NSMutableDictionary*)atts withDefaultURI:(NSString*)default_uri NS_RETURNS_RETAINED;
@end

@interface BufferParser : NSObject <XMLElementStreamListener>
{
    BOOL _finished;
    XMLElement* _root;
    XMLElementStream* _stream;
}
-(id) init;

-(XMLElement*) process:(const char*)data;

-(void) onDocumentStart:(XMLElement*)element;
-(void) onElement:(XMLElement*)element;
-(void) onCData:(XMLCData*)cdata;
-(void) onDocumentEnd;
@end

@implementation BufferParser
-(id) init
{
    if (self = [super init])
	{
		_stream = [[XMLElementStream alloc] initWithListener:self];
	}
    return self;
}

-(XMLElement*) process:(const char*)data
{
    [_stream pushData:data];
    if (!_finished)
    {
        NSLog(@"Exception in [XMLElementStream parseDataAtOnce]");
        assert(0);
    }
    return _root;
}

-(void) onDocumentStart:(XMLElement*)element
{
    _root = element;
}

-(void) onElement:(XMLElement*)element
{
    [_root appendChildNode:element];
}

-(void) onCData:(XMLCData*)cdata
{
    [_root appendChildNode:cdata];
}

-(void) onDocumentEnd
{
    _finished = true;
}
@end

static void _handleOpenElement(void* data, const char* name, const char** atts)
{
    XMLElementStream* parser = (__bridge XMLElementStream*)data;
    [parser openElement:name withAttributes: atts];
}

static void _handleCloseElement(void* data, const char* name)
{
    XMLElementStream* parser = (__bridge XMLElementStream*)data;
    [parser closeElement:name];
}

static void _storeCData(void* data, const XML_Char* s, int len)
{
    XMLElementStream* parser = (__bridge XMLElementStream*)data;
    [parser storeCData:(char*)s ofLength:len];
}

static void _handleEnterNamespace(void* data, const XML_Char* prefix, 
                                  const XML_Char* uri)
{
    XMLElementStream* parser = (__bridge XMLElementStream*)data;
    [parser enterNamespace:prefix withURI:uri];
}

static void _handleExitNamespace(void* data, const XML_Char* prefix)
{
    XMLElementStream* parser = (__bridge XMLElementStream*)data;
    [parser exitNamespace:prefix];
}

@interface XMLElementStream ()
+(XMLElement*) factoryCreateElement:(XMLQName*)qname withAttributes:(NSMutableDictionary*)atts
					 withDefaultURI:(NSString*)defaultURI NS_RETURNS_RETAINED;

@end

@implementation XMLElementStream
{
    BOOL _document_started;
    BOOL _document_ended;
    
    void*       _parser;
    XMLElement*      _current_element;
    
    NSMutableArray*  _default_uri_stack;
    
    __weak id<XMLElementStreamListener> _listener;
}
static NSMutableArray* G_FACTORY;

+(void) registerElementFactory:(Class)factory
{
    [G_FACTORY addObject:factory];
}


+(void) initialize
{
    G_FACTORY = [[NSMutableArray alloc] init];
}

-(instancetype) init
{
	if (!(self = [super init])) return nil;

    _default_uri_stack = [[NSMutableArray alloc] initWithCapacity: 5];

    // Startup parser
    [self reset];
    
    return self;
}

-(void) dealloc
{
    if (_parser)
        XML_ParserFree(_parser);
}

-(instancetype) initWithListener: (id <XMLElementStreamListener>) listener
{
	if (!(self = [self init])) return nil;

    // Assign pointer to _listener
    _listener = listener;

    return self;    
}

-(void) enterNamespace:(const char*)prefix withURI:(const char*)uri
{
    if (prefix == NULL)
    {
        NSString* uristr = @(uri);
        [_default_uri_stack addObject:uristr];
    }
}

-(void) exitNamespace:(const char*)prefix
{
    if (prefix == NULL)
    {
        [_default_uri_stack removeLastObject];
    }
}

+(XMLElement*) factoryCreateElement:(XMLQName*)qname withAttributes:(NSMutableDictionary*)atts
                     withDefaultURI:(NSString*)defaultURI
{
    // Walk all registered element handlers asking each one to take a peek and see if they want
    // to instantiate this element; only one gets the opportunity
	for (Class cur in G_FACTORY) {
		XMLElement* result = [cur constructElement:qname withAttributes:atts withDefaultURI:defaultURI];
        if (result != nil)
            return result;
    }
    // Matching element handlers found, create w/ default
    return [[XMLElement alloc] initWithQName:qname
                             withAttributes:atts
                             withDefaultURI:defaultURI];
}

-(void) openElement: (const char*)name withAttributes:(const char**) atts
{
    int i = 0;
    XMLElement* new_element;
    NSMutableDictionary* new_element_attribs = [NSMutableDictionary dictionary];
    NSString* default_uri = [self currentNamespaceURI];
    XMLQName* qname = [XMLQName construct:name];

    // Parse out the element attributes -- we do this inside the stream so that
    // we can have more information available to select the specialized class
    // for this stanza
    while (atts[i] != '\0')
    {
        XMLQName* key = [XMLQName construct:atts[i] withDefaultURI:default_uri];
        NSString* value = @(atts[i+1]);
        new_element_attribs[key] = value;
        i += 2;
    }

    // Construct the new element, using the factory to pick the appropriate subclass
    new_element = [XMLElementStream factoryCreateElement:qname
                                    withAttributes:new_element_attribs
                                    withDefaultURI:default_uri];
    
    // If the document has started...
    if (_document_started)
    {
        // Packet is already being built
        if (_current_element)
        {
            _current_element = [_current_element addElement:new_element];
        }
        // Starting a new packet
        else
        {
            _current_element = new_element;
        }
    }
    // Document has NOT started; we need to generate a document start event
    else
    {
        _document_started = TRUE;
        [_listener onDocumentStart:new_element];
    }
}

-(void) closeElement: (const char*) name
{
    // At least one Element exists above the current one; this event
    // is just closing an Element within the packet
    if ([_current_element parent])
    {
        _current_element = [_current_element parent];
    }
    // There is a current_element, but no parent; this event is
    // closing an immediate child of the root (i.e. a packet)
    else if (_current_element)
    {
        [_current_element setup];
        [_listener onElement:_current_element];
        _current_element = nil;
    }
    // No current_element and no parents; this event is closing the
    // document 
    else
    {
        [_listener onDocumentEnd];
        _document_ended = TRUE;
    }
}

-(void) storeCData: (char*) cdata ofLength:(NSInteger) len
{
    if (_current_element)
        [_current_element addCData:cdata ofLength:len];
    else
    {
        XMLCData* data = [[XMLCData alloc] initWithCharPtr:cdata ofLength:len];
        [_listener onCData:data];
    }
}

-(void) pushData: (const char*)data ofSize:(NSUInteger)datasz
{
    assert(_document_ended != TRUE);
    if (!XML_Parse(_parser, data, (int)datasz, 0))
    {
        NSLog(@"Parser Error: %s", XML_ErrorString(XML_GetErrorCode(_parser)));
    }
}

-(void) pushData: (const char*)data
{
    [self pushData:data ofSize:strlen(data)];
}

-(void) reset
{
    _document_started = FALSE;
    _document_ended   = FALSE;

    if (_parser)
        XML_ParserFree(_parser);

    // Setup the expat parser
    _parser = XML_ParserCreateNS(NULL, '|');
    XML_SetUserData(_parser, (__bridge void *)(self));
    XML_SetElementHandler(_parser, _handleOpenElement, _handleCloseElement);
    XML_SetCharacterDataHandler(_parser, _storeCData);
    XML_SetNamespaceDeclHandler(_parser, _handleEnterNamespace, 
                                _handleExitNamespace);


    // Clear out the URI stack
    [_default_uri_stack removeAllObjects];
}

+(XMLElement*) parseDataAtOnce: (const char*)buffer
{
    XMLElement* e;
    BufferParser* p = [[BufferParser alloc] init];
    e = [p process:buffer];
    return e;
}

-(NSString*) currentNamespaceURI
{
    return [_default_uri_stack lastObject];
}

@end
