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
// $Id: XMLCData.m,v 1.5 2004/12/31 20:55:12 alangh Exp $
//============================================================================
#import "acid-dom.h"
#import "NSString+Misc.h"

@implementation XMLCData
{
    NSMutableString* _text; // CData is stored as escaped text
}
// Basic initializers
-(instancetype) init
{
    self = [super init];
    return self;
}

// Custom initializers
-(instancetype) initWithString:(NSString*)s  // Assumes unescaped data
{
	if (!(self = [self init])) return nil;

    _text = [[NSMutableString alloc] initWithString:s];
    return self;
}

 
-(instancetype) initWithCharPtr:(const char*)cptr ofLength:(NSUInteger)clen  // Assumes unescaped data
{
	if (!(self = [self init])) return nil;
    _text = [[NSMutableString alloc] initWithUTF8String:cptr length:clen];
    return self;
}

-(instancetype) initWithEscapedCharPtr:(const char*)cptr ofLength:(NSUInteger)clen
{
	if (!(self = [self init])) return nil;
    _text = [XMLCData unescape:cptr ofLength:clen];
    return self;
}


// Modify text using data that is _not_ escaped
-(void) setText:(const char*)text ofLength:(NSUInteger)textlen
{
    if (textlen == 0)
        _text = [[NSMutableString alloc] initWithUTF8String:text];
    else
        _text = [[NSMutableString alloc] initWithUTF8String:text length:textlen];
}

-(void) setText:(NSString*)text
{
    _text = [[NSMutableString alloc] initWithString:text];
}

-(void) appendText:(const char*)text ofLength:(NSUInteger)textlen
{
    NSString* s = [[NSString alloc] initWithUTF8StringNoCopy:(char*)text length:textlen
                                             freeWhenDone:NO];
    [_text appendString:s];
}

-(void) appendText:(NSString*)text
{
    [_text appendString:text];
}

// Modify text using data that is escaped
-(void) setEscapedText:(const char*)text ofLength:(NSUInteger)textlen
{
    _text = [XMLCData unescape:text ofLength:textlen];
}

-(void) appendEscapedText:(const char*)text ofLength:(NSUInteger)textlen
{
    [_text appendString: [XMLCData unescape:text ofLength:textlen]];
}

-(NSString*) text  // Unescaped text
{
    return _text;
}

-(NSString*) description  // Escaped text
{
    return [XMLCData escape:_text];
}

// Implementation of XMLNode protocol
-(XMLQName*) qname
{
    XMLQName* result = [[XMLQName alloc] initWithName:@"#CDATA" inURI:@""];
    return result;
}

-(NSString*) name
{
    return @"#CDATA";
}

-(NSString*) uri
{
    return @"";
}

-(void) description:(XMLAccumulator*)acc
{
    [acc addCData:self];
}

+(NSString*) escape:(const char*)data ofLength:(NSInteger)datasz
{
    NSInteger i, j, newlen;
    char* temp;
    NSString* result;

    if (datasz == 0)
        datasz = strlen(data);

    newlen = datasz;
    for (i = 0; i < datasz; ++i)
    {
        switch(data[i])
        {
        case '&':
            newlen+=5;
            break;
        case '\'':
            newlen+=6;
            break;
        case '\"':
            newlen+=6;
            break;
        case '<':
            newlen+=4;
            break;
        case '>':
            newlen+=4;
            break;
        }
    }

    // If, after calculating the escaped length, the length hasn't
    // changed, we can shortcircuit outta here
    if (newlen == datasz)
    {
        result = [[NSString alloc] initWithUTF8String:data length:datasz];
        return result;
    }

    temp = (char*)malloc(newlen + 1);

    for (i = j = 0; i < datasz; ++i)
    {
        switch(data[i])
        {
        case '&':
            memcpy(&temp[j],"&amp;",5);
            j += 5;
            break;
        case '\'':
            memcpy(&temp[j],"&apos;",6);
            j += 6;
            break;
        case '\"':
            memcpy(&temp[j],"&quot;",6);
            j += 6;
            break;
        case '<':
            memcpy(&temp[j],"&lt;",4);
            j += 4;
            break;
        case '>':
            memcpy(&temp[j],"&gt;",4);
            j += 4;
            break;
        default:
            temp[j++] = data[i];
        }
    }
    temp[j] = '\0';

    result = [[NSString alloc] initWithUTF8StringNoCopy:temp 
                               length:newlen
                               freeWhenDone:TRUE];

    return result;
}

+(NSString*) escape:(NSString*)data
{
    NSUInteger i, j, newlen, oldlen;
    char *temp;
    const char *cdata;
    NSString* result;

    if (data == nil)
        return nil;
        
    cdata = [data UTF8String];
    newlen = oldlen = strlen(cdata);
    for (i = 0; i < oldlen; ++i)
    {
        switch(cdata[i])
        {
        case '&':
            newlen+=4;
            break;
        case '\'':
            newlen+=5;
            break;
        case '\"':
            newlen+=5;
            break;
        case '<':
            newlen+=3;
            break;
        case '>':
            newlen+=3;
            break;
        }
    }

    // If, after calculating the escaped length, the length hasn't
    // changed, we can shortcircuit outta here
    if (newlen == oldlen)
    {
        return data;
    }

    temp = (char *)malloc(newlen + 1);

    for (i = j = 0; i < oldlen; ++i)
    {
        char current = cdata[i];
        switch(current)
        {
        case '&':
            memcpy(&temp[j],"&amp;",5);
            j += 5;
            break;
        case '\'':
            memcpy(&temp[j],"&apos;",6);
            j += 6;
            break;
        case '\"':
            memcpy(&temp[j],"&quot;",6);
            j += 6;
            break;
        case '<':
            memcpy(&temp[j],"&lt;",4);
            j += 4;
            break;
        case '>':
            memcpy(&temp[j],"&gt;",4);
            j += 4;
            break;
        default:
            temp[j++] = current;
        }
    }
    temp[j] = '\0';

    result = [[NSString alloc] initWithUTF8StringNoCopy:temp 
                               length:newlen
                               freeWhenDone:TRUE];

    return result;
}

+(NSMutableString*) unescape:(const char*)data ofLength:(NSInteger)datasz
{
    NSInteger i,j=0;
    char *temp;
    NSMutableString* result;

    if (datasz == 0)
        datasz = strlen(data);

    // This costs an extra scan, but considering how many function
    // calls this would avoid, I suspect it would be worth it
    if (strchr(data,'&') == NULL) 
    {
        result = [[NSMutableString alloc] initWithUTF8String:data 
                                          length:datasz];
        return result;
    }


    temp = (char*)malloc(datasz);

    for(i = 0; i < datasz;i++)
    {
        if (data[i]=='&')
        {
            if (strncmp(&data[i],"&amp;",5)==0)
            {
                temp[j] = '&';
                i += 4;
            } else if (strncmp(&data[i],"&quot;",6)==0) {
                temp[j] = '\"';
                i += 5;
            } else if (strncmp(&data[i],"&apos;",6)==0) {
                temp[j] = '\'';
                i += 5;
            } else if (strncmp(&data[i],"&lt;",4)==0) {
                temp[j] = '<';
                i += 3;
            } else if (strncmp(&data[i],"&gt;",4)==0) {
                temp[j] = '>';
                i += 3;
            }
        } else {
            temp[j]=data[i];
        }
        j++;
    }
    temp[j]='\0';

    result = [[NSMutableString alloc] initWithUTF8StringNoCopy:temp
                                      length:j
                                      freeWhenDone:TRUE];

    return result;
}

@end
