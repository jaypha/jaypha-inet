//Written in the D programming language
/*
 * MIME Content-Type header.
 *
 * Copyright: Copyright (C) 2013 Jaypha
 *
 * Distributed under the Boost Software License, Version 1.0.
 * (See http://www.boost.org/LICENSE_1_0.txt)
 *
 * Authors: Jason den Dulk
 */

/*
 * RFCs : 2045
 */

module jaypha.inet.mime.contenttype;

import jaypha.inet.mime.reading;
import jaypha.inet.imf.writing;

import std.array;

//-----------------------------------------------------------------------------
// Content Type info

struct MimeContentType
{
  enum headerName = "Content-Type";

  string mimeType = "text/plain";
  string[string] parameters;
}

//----------------------------------------------------------------------------
// extracts the content of a Content-Type MIME header.

MimeContentType extractMimeContentType(string fieldBody)
{
  MimeContentType ct;

  skipSpaceComment(fieldBody);
  auto type = extractToken(fieldBody);
  skipSpaceComment(fieldBody);
  if (fieldBody.cfront != '/') throw new Exception("malformed MIME header");
  fieldBody.popFront();
  skipSpaceComment(fieldBody);
  auto subType = extractToken(fieldBody); // TODO, the delimiter in this case is whitespace.
  ct.mimeType = type~"/"~subType;
  extractMimeParams(fieldBody,ct.parameters);
  return ct;
}

//----------------------------------------------------------------------------

MimeHeader toMimeHeader(ref MimeContentType contentType, bool asImf = false)
{
  auto a = appender!string;
  a.put(contentType.mimeType);
  foreach (i,v; contentType.parameters)
    a.put("; "~i~"=\""~v~"\"");

  if (asImf)
    return unstructuredHeader(MimeContentType.headerName,a.data);
  else
    return MimeHeader(MimeContentType.headerName,a.data);
}

//----------------------------------------------------------------------------
