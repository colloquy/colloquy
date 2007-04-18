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
//     Copyright (C) 2002 Dave Smith (dizzyd@jabber.org)
// 
// $Id: acid-dom.h,v 1.2 2004/10/16 21:09:47 alangh Exp $
//============================================================================

#import <Foundation/Foundation.h>
/* Fire Specific change to get rid of cdecl warnings */
#define XMLCALL
#import <expat.h>

@interface XMLQName : NSObject <NSCopying>
{
    NSString* _name;
    NSString* _uri;
}

-(id) initWithName:(NSString*)name inURI:(NSString*)uri;
-(void) dealloc;

-(NSString*)name;
-(NSString*)uri;

-(NSString*)description;

-(id) copyWithZone:(NSZone*)zone;

-(BOOL) isEqual:(XMLQName*)other;
-(NSComparisonResult) compare:(id)other;

+(XMLQName*) construct:(NSString*)name withURI:(NSString*)uri;
+(XMLQName*) construct:(const char*)name;
+(XMLQName*) construct:(const char*)expatname withDefaultURI:(NSString*)uri;
@end

#define QNAME(uri, elem) [XMLQName construct:elem withURI:uri]

@class XMLAccumulator;

@protocol XMLNode
-(XMLQName*) qname;
-(NSString*) name;
-(NSString*) uri;
-(void)      description:(XMLAccumulator*)acc;
@end



@interface XMLCData : NSObject <XMLNode>
{
    NSMutableString* _text; // CData is stored as escaped text
}

// Basic initializers
-(id)   init;
-(void) dealloc;

// Custom initializers
-(id) initWithString:(NSString*)s; // Assumes unescaped data
-(id) initWithCharPtr:(const char*)cptr ofLength:(unsigned)clen; // Assumes unescaped data
-(id) initWithEscapedCharPtr:(const char*)cptr ofLength:(unsigned)clen;

// Modify text using data that is _not_ escaped
-(void) setText:(const char*)text ofLength:(unsigned)textlen;
-(void) setText:(NSString*)text;
-(void) appendText:(const char*)text ofLength:(unsigned)textlen;
-(void) appendText:(NSString*)text;

// Modify text using data that is escaped
-(void) setEscapedText:(const char*)text ofLength:(unsigned)textlen;
-(void) appendEscapedText:(const char*)text ofLength:(unsigned)textlen;

-(NSString*) text; // Unescaped text

-(NSString*) description; // Escaped text

// Implementation of XMLNode protocol
-(XMLQName*) qname;
-(NSString*) name;
-(NSString*) uri;
-(void)      description:(XMLAccumulator*)acc;

// Escaping routines
+(NSString*) escape:(const char*)data ofLength:(int)datasz;
+(NSString*) escape:(NSString*)data;
+(NSMutableString*) unescape:(const char*)data ofLength:(int)datasz;

@end


@interface XMLElement : NSObject <XMLNode>
{
    NSMutableDictionary* _attribs;  // XMLQName->NSString
    NSMutableArray*      _children;
    XMLElement*          _parent;
    XMLQName*            _name;
    NSString*            _defaultURI;
    NSMutableDictionary* _namespaces; // NSString:URI->NSString:prefix
}

// Basic initializers
-(id)   init;
-(void) dealloc;

// Extended initializers
-(id) initWithQName:(XMLQName*)qname
     withAttributes:(NSMutableDictionary*)atts
     withDefaultURI:(NSString*)uri;

-(id) initWithQName:(XMLQName*)qname;

-(id) initWithQName:(XMLQName*)qname withDefaultURI:(NSString*)uri;

// High-level child initializers
-(XMLElement*) addElement:(XMLElement*)element;
-(XMLElement*) addElementWithName:(NSString*)name;
-(XMLElement*) addElementWithQName:(XMLQName*)name;
-(XMLElement*) addElementWithName:(NSString*)name withDefaultURI:(NSString*)uri;
-(XMLElement*) addElementWithQName:(XMLQName*)name withDefaultURI:(NSString*)uri;

-(XMLCData*)   addCData:(const char*)cdata ofLength:(unsigned)cdatasz;
-(XMLCData*)   addCData:(NSString*)cdata;

// Enumerators
-(NSEnumerator*) childElementsEnumerator;

// Raw child management
-(id<XMLNode>) firstChild;
-(void) appendChildNode:(id <XMLNode>)node;
-(void) detachChildNode:(id <XMLNode>)node;

// Child node info
-(BOOL)     hasChildren;
-(unsigned) childCount;

// Namespace declaration management
-(void) addNamespaceURI:(NSString*)uri withPrefix:(NSString*)prefix;
-(void) delNamespaceURI:(NSString*)uri;

// Attribute management
-(void)      putAttribute:(NSString*)name withValue:(NSString*)value;
-(NSString*) getAttribute:(NSString*)name;
-(void)      delAttribute:(NSString*)name;
-(BOOL)      cmpAttribute:(NSString*)name withValue:(NSString*)value;

-(void)      putQualifiedAttribute:(XMLQName*)qname withValue:(NSString*)value;
-(NSString*) getQualifiedAttribute:(XMLQName*)qname;
-(void)      delQualifiedAttribute:(XMLQName*)qname;
-(BOOL)      cmpQualifiedAttribute:(XMLQName*)qname withValue:(NSString*)value;


// Convert this node to string representation
-(NSString*) description;

// Implementation of XMLNode protocol
-(XMLQName*) qname;
-(NSString*) name;
-(NSString*) uri;
-(void)      description:(XMLAccumulator*)acc;

// Extract first child CDATA from this Element
-(NSString*) cdata;

// Convert a name and uri into a XMLQName structure
-(XMLQName*) getQName:(NSString*)name ofURI:(NSString*)uri;
-(XMLQName*) getQName:(const char*)expatname;

-(XMLElement*) parent;
-(void)        setParent:(XMLElement*)elem;
-(NSString*)   defaultURI;

-(NSString*) addUniqueIDAttribute;

-(void) setup;

@end


@interface XMLAccumulator : NSObject
{
    NSMutableString*     _data;
    NSMutableDictionary* _prefixes; // uri -> prefix
    NSMutableDictionary* _overrides;
    unsigned             _prefix_counter;
}

-(id) init:(NSMutableString*)data;
-(void) dealloc;

-(void) addOverridePrefix:(NSString*)prefix forURI:(NSString*)uri;
-(NSString*) generatePrefix:(NSString*)uri;

-(void) openElement:(XMLElement*)elem;
-(void) closeElement:(XMLElement*)elem;
-(void) addAttribute:(XMLQName*)qname withValue:(NSString*)value ofElement:(XMLElement*)elem;
-(void) addChildren:(NSArray*)children ofElement:(XMLElement*)elem;
-(void) addCData:(XMLCData*)cdata;

+(NSString*) process:(XMLElement*)element;

@end

@protocol XMLElementStreamListener
-(void) onDocumentStart:(XMLElement*)element;
-(void) onElement:(XMLElement*)element;
-(void) onCData:(XMLCData*)cdata;
-(void) onDocumentEnd;
@end

@interface XMLElementStream : NSObject 
{
    BOOL _document_started;
    BOOL _document_ended;

    XML_Parser       _parser;
    XMLElement*      _current_element;

    NSMutableArray*  _default_uri_stack;
    
    id<XMLElementStreamListener> _listener;
}

+(void) registerElementFactory:(Class)factory;

-(id)   init;
-(void) dealloc;

-(id) initWithListener: (id<XMLElementStreamListener>)listener;

-(void) pushData: (const char*)data ofSize:(unsigned int)datasz;
-(void) pushData: (const char*)data;
-(void) reset;

+(XMLElement*) parseDataAtOnce: (const char*)buffer;

-(void) openElement: (const char*)name withAttributes:(const char**) atts;
-(void) closeElement: (const char*) name;
-(void) storeCData: (char*) cdata ofLength:(int) len;
-(void) enterNamespace: (const char*)prefix withURI:(const char*)uri;
-(void) exitNamespace: (const char*)prefix;

-(NSString*) currentNamespaceURI;

@end



