//Written in the D programming language
/*
 * Routintes for reading and parsing MIME documents.
 *
 * Copyright: Copyright (C) 2013-2014 Jaypha
 *
 * Distributed under the Boost Software License, Version 1.0.
 * (See http://www.boost.org/LICENSE_1_0.txt)
 *
 * Authors: Jason den Dulk
 */

module jaypha.inet.mime.reading;

public import jaypha.inet.mime.header;

enum mimeSpecials = "()<>@,;:\\\".[]";  // from RFC822
enum mimetSpecials = "()<>@,;:\\\"/[]?=";  //  from RFC2045
enum mimeLwsp = " \t";
enum mimeDelimeters = mimeSpecials ~ mimeLwsp;
enum mimeTokenDelimeters = mimetSpecials ~ mimeLwsp;

import std.array;
import std.string;
import std.range;
import std.algorithm;
import std.traits;

//-----------------------------------------------------------------------------
// extracts MIME parameters.
// Parameters are of the format *(';' atrribute '=' value)
// value = token / quoted-string.
// TODO updated def in RFC2231

void extractMimeParams(string source, ref string[string] parameters)
{
  skipSpaceComment(source);
  while (!source.empty && source.front == ';')
  {
    source.popFront();
    source.skipSpaceComment();
    auto attribute = source.extractToken();
    source.skipSpaceComment();
    if (source.cfront != '=') throw new Exception("malformed MIME header");
    source.popFront();
    source.skipSpaceComment();
    if (source.cfront == '\"')
      parameters[attribute] = source.extractQuotedString();
    else
      parameters[attribute] = source.extractToken();
    source.skipSpaceComment();
  }
}

//-----------------------------------------------------------------------------

unittest
{
  string t1 = "; bean  = (not this)rock ";
  string t2 = ";dog(canine)  = \"A (canine) animal\"  ";
  string t3 = " ;(c)rabbit=jack;jack=\"\"";
  string t4 = ";";

  string[string] parms;

  extractMimeParams(t1,parms);
  assert("bean" in parms);
  assert(parms["bean"] = "rock");

  extractMimeParams(t2,parms);
  assert("dog" in parms);
  assert(parms["dog"] = "A (canine) animal");

  extractMimeParams(t3,parms);
  assert("rabbit" in parms);
  assert("jack" in parms);
  assert(parms["rabbit"] == "jack");
  assert(parms["jack"].empty);

  try {
    extractMimeParams(t4,parms);
    assert(false);
  } catch (Exception e) {
  }
}

//-----------------------------------------------------------------------------
// Extracts a MIME token from the input string.

string extractToken(ref string source)
{
  auto remainder = findAmong(source, mimeTokenDelimeters);
  auto token = source[0..$-remainder.length];
  if (token.empty) throw new Exception("malformed MIME header");
  source = remainder;
  return token;
}

//-----------------------------------------------------------------------------
// Extracts a quoted string token from the input string.

string extractQuotedString(ref string source)
{
  auto s = appender!string();

  source.popFront(); // front should be a \".
  while (source.cfront != '\"')
  {
    if (source.front == '\\')
      source.popFront();
    s.put(source.cfront());
    source.popFront();
  }
  source.popFront(); // front should be a \".
  return s.data;
}

//-----------------------------------------------------------------------------

unittest
{
  string t1 = "john@";
  string t2 = "\" a quoted \\\" string\"g";
  string t3 = "\"unfinished";

  assert(extractToken(t1) == "john");
  assert(t1 == "@");

  assert(extractQuotedString(t2) == " a quoted \" string");
  assert(t2 == "g");

  try
  {
    extractQuotedString(t3);
    assert(false);
  } catch (Exception e)
  {
    assert(t3.empty);
  }

  try
  {
    t3 = "";
    extractToken(t3);
    assert(false);
  } catch (Exception e)
  {
    assert(t3.empty);
  }

  try
  {
    t3 = "";
    extractToken(t3);
    assert(false);
  } catch (Exception e)
  {
    assert(t3.empty);
  }
}

//-----------------------------------------------------------------------------
// Skips all contiguous spaces and comments.

void skipSpaceComment(ref string source)
{
  skipSpace(source);
  while (!source.empty && source.front == '(')
  {
    ulong count = 1;
    source.popFront();
    do
    {
      if (source.cfront == '\\')
        source.popFront();
      else
      {
        if (source.front == '(')
          ++count;
        else if (source.front == ')')
          --count;
      }
      source.cpopFront();
    } while (count != 0);
    skipSpace(source);
  }
}

//-----------------------------------------------------------------------------

void skipSpace(ref string source)
{
  while (!source.empty && inPattern(source.front, mimeLwsp))
    source.popFront();
}

//-----------------------------------------------------------------------------

unittest
{
  string t1 = "  xyz";
  string t2 = "   (comment1) (comment (2)(2))(tricky \\) comment)  non-comment";
  string t3 = "(unfinished comment";
  
  skipSpace(t1);
  assert(t1 == "xyz");

  skipSpaceComment(t2);
  assert(t2 == "non-comment");

  try {
    skipSpaceComment(t3);
    assert(false);
  } catch(Exception e)
  {
    assert(t3.empty);
  }
}

//-----------------------------------------------------------------------------
// "compulsory" front and popFront. Spits the dummy if empty.

auto cfront(R)(ref R range) if (isInputRange!R)
{
  if (range.empty) throw new Exception("malformed MIME header");
  return range.front;
}

void cpopFront(R)(ref R range) if (isInputRange!R)
{
  if (range.empty) throw new Exception("malformed MIME header");
  range.popFront();
}

//-----------------------------------------------------------------------------
// Reads in headers from a MIME document. Unfolds multiline headers, but
// does not perform any other lexing of header field bodies.
// Does consume the empty line following headers.
// TODO: Allow to read from strings as well as octect streams.

MimeHeader[] parseMimeHeaders(BR)(ref BR reader)
  if ((isInputRange!BR && is(ElementType!BR : ubyte)))
{
  MimeHeader[] headers;
  /* Read headers until we get to a blank line */

  while (true)
  {
    auto buf = jaypha.algorithm.findSplit(reader, cast(ubyte[])MimeEoln);
    if (buf[1] != cast(ubyte[]) MimeEoln) throw new Exception("malformed Mime Header");

    if (buf[0].length == 0) break;

    auto header = cast(string) buf[0];

    if (inPattern(header[0], mimeLwsp))
    {
      // leading whitespace means s part of the previous header.
      headers[$-1].fieldBody ~= header;
    }
    else
    {
      auto buf2 = std.algorithm.findSplit(header,":");
      if (buf2[1] != ":") throw new Exception("malformed Mime Header");
      headers ~= MimeHeader(buf2[0], buf2[2]);
    }
  }
  return headers;
}

//-----------------------------------------------------------------------------

unittest
{
  string entity_text =
    "Content-Type: text/plain; charset=us-ascii\r\n"
    "Content-Disposition: blah blah \r\n"
    "\tblah\r\n"
    "\r\n"
    "This is explicitly typed plain US-ASCII text.\r\n"
    "It DOES end with a linebreak.\r\n";

  //auto r1 = inputRangeObject(cast(ubyte[]) entity_text.dup);
  auto r1 = cast(ubyte[]) entity_text;

  auto headers = parseMimeHeaders(r1);
  assert(headers.length == 2);
  assert(headers[0].name == "Content-Type");
  assert(headers[0].fieldBody == " text/plain; charset=us-ascii");
  assert(headers[1].name == "Content-Disposition");
  assert(headers[1].fieldBody == " blah blah \tblah");
  assert(r1.front == 'T');
}

//-----------------------------------------------------------------------------
// Entity Reader. Takes an input range representing a MIME document, extracts
// the headers and presents the rest for further reading.

auto mimeEntityReader(BR)(BR reader)
  if ((isInputRange!BR && is(ElementType!BR : ubyte)))
{
  return MimeEntityReader!(BR)(parseMimeHeaders(reader),reader);
}

struct MimeEntityReader(BR)
{
  MimeHeader[] headers;
  BR content;
}

//-----------------------------------------------------------------------------

unittest
{
  import std.stdio;
  import std.exception;
  import std.array;
  import std.algorithm;
  import std.range;

  string entity_text =
    "Content-Type: text/plain; charset=us-ascii\r\n"
    "Content-Disposition: blah blah \r\n"
    "\tblah\r\n"
    "\r\n"
    "This is explicitly typed plain US-ASCII text.\r\n"
    "It DOES end with a linebreak.\r\n";

  auto r1 = inputRangeObject(cast(ubyte[]) entity_text.dup);

  auto entity = mimeEntityReader(r1);

  static assert(is(typeof(entity.content) == typeof(r1)));
  assert(entity.headers.length == 2);
  assert(entity.headers[0].name == "Content-Type");
  assert(entity.headers[0].fieldBody == " text/plain; charset=us-ascii");
  assert(entity.headers[1].name == "Content-Disposition");
  assert(entity.headers[1].fieldBody == " blah blah \tblah");

  auto buff = appender!(ubyte[]);

  entity.content.copy(buff);
  assert(buff.data == 
    "This is explicitly typed plain US-ASCII text.\r\n"
    "It DOES end with a linebreak.\r\n");
}

//-----------------------------------------------------------------------------
// Multipart Entity Reader. Takes an input range and converts it into an
// input range of Mime Entity Readers. Each element represents a Mime Entity.
// Presumes that headers of the primary entity have already been extracted.
// TODO: See if a way can be found to preserve the preamble and epilogue.

import jaypha.algorithm;
import jaypha.range;

auto mimeMultipartReader(BR)(ref BR reader, string boundary)
  if (isInputRange!BR && is(ElementType!BR : ubyte))
{
  string full_boundary = "\r\n--"~boundary;

  jaypha.algorithm.findSplit(reader, full_boundary[2..$]);
  jaypha.algorithm.findSplit(reader, "\r\n"); // skip over whitespace, but don't bother checking.

  auto entity = mimeEntityReader(readUntil(reader, full_boundary));

  alias typeof(entity) T;

  struct MR
  {
    @property bool empty() { return reader.empty; }

    @property T front() { return entity; }

    void popFront()
    {
      if (!entity.content.empty) entity.content.drain(); // In case the user pops before fully reading the entity

      auto rem = jaypha.algorithm.findSplit(reader, MimeEoln); // skip over whitespace, but don't bother checking.
      bool last_time = startsWith(rem[0], "--");
      if (!last_time)
      {
        if (rem[1] != MimeEoln) throw new Exception("malformed MIME Entity");
        entity = mimeEntityReader(readUntil(reader, full_boundary));
      }
      else
      {
        reader.drain(); // Skip epilogue;
      }
    }
  }
  return MR();
}

//----------------------------------------------------------------------------
// Advances the input range until sentinal is found

private bool skipOverUntil(Reader)(ref Reader r, string sentinel)
{
  while (true)
  {
    if (cast(char)r.front == sentinel[0])
      for (uint i=0; i<=sentinel.length; ++i)
      {
        if (i == sentinel.length)
          return true;
        if (r.empty)
          return false;

        if (cast(char)r.front != sentinel[i])
          break;

        r.popFront();
        if (r.empty)
          return false;
      }
    else
    {
      r.popFront();
      if (r.empty)
        return false;
    }
  }
}


unittest
{

  string preamble =
    "This is the preamble.  It is to be ignored, though it\r\n"
    "is a handy place for composition agents to include an\r\n"
    "explanatory note to non-MIME conformant readers.\r\n"
    "\r\n"
    "--simple boundary  \t  \t\t \r\n"
    "\r\n"
    "This is implicitly typed plain US-ASCII text.\r\n"
    "It does NOT end with a linebreak.\r\n"
    "--simple boundary\r\n"
    "Content-type: text/plain; charset=us-ascii\r\n"
    "\r\n"
    "This is explicitly typed plain US-ASCII text.\r\n"
    "It DOES end with a linebreak.\r\n"
    "\r\n"
    "--simple boundary--\r\n"
    "\r\n"
    "This is the epilogue.  It is also to be ignored.\r\n";

  string preamble2 = "--simple boundary\r\nZBC";

  auto buff = appender!(ubyte[]);

  ubyte[] txt = cast(ubyte[]) "acabacbxyz".dup;

  string y = "abc";

  auto r1 = inputRangeObject(txt);

  auto x = r1.skipOverUntil("cbx");
  assert(x);
  r1.copy(buff);
  assert(cast(char[])(buff.data) == "yz");

  buff.clear();

  txt = cast(ubyte[]) "acabacbxyz".dup;
  r1 = inputRangeObject(txt);

  assert(!r1.skipOverUntil("c1bx"));
  assert(r1.empty);

  txt = cast(ubyte[]) preamble.dup;
  r1 = inputRangeObject(txt);

  auto r2 = mimeMultipartReader(r1, "simple boundary");


  assert(r1.front == cast(ubyte)'T');
  auto r3 = r2.front;

  assert(r3.headers.length == 0);
  put(buff,r3.content);
  assert(buff.data == "This is implicitly typed plain US-ASCII text.\r\n"
    "It does NOT end with a linebreak.");
  assert(r3.content.empty);
  assert(r1.front == cast(ubyte)'\r');

  buff.clear();
  r2.popFront();
  r3 = r2.front;
  assert(r3.headers.length == 1);
  
  r3.content.copy(buff);

  assert(buff.data ==
    "This is explicitly typed plain US-ASCII text.\r\n"
    "It DOES end with a linebreak.\r\n");
  assert(r3.content.empty);
  r2.popFront();
  assert(r2.empty);
  assert(r1.empty);

}

//----------------------------------------------------------------------------
// Comsumes the front of the range as long as it matches the given prefix
// Returns whether or not the entire prefix got matches. If all_or_nothing is
// true, then an exception occurs if prefix is nto matched in its entirely.
// Designed to work with ranges that cannot be rewound.

bool skipOverAnyway(R)(ref R r, string prefix, bool all_or_nothing = false)
 if (isInputRange!R)
{
  if (r.empty || r.front != prefix[0])
    return false;

  uint i = 0;
  do
  {
    r.popFront();
    ++i;
  } while (i < prefix.length && !r.empty && r.front == prefix[i]);

  if (i == prefix.length) return true;
  if (all_or_nothing) throw new Exception("malformed MIME Entity");
  return false;
}

unittest
{
  ubyte[] txt = cast(ubyte[]) "acabacbxyz".dup;
  auto r1 = inputRangeObject(txt);
  auto buff = appender!(ubyte[])();

  assert(skipOverAnyway(r1, "aca"));
  assert(!skipOverAnyway(r1, "baa"));
  assert(!skipOverAnyway(r1, "xyz"));
  try {
    skipOverAnyway(r1,"cbz",true);
    assert(false);
  } catch (Exception e) {
  }
  r1.copy(buff);
  assert(cast(char[])(buff.data) == "xyz");
}

//----------------------------------------------------------------------------
// An alternative to std.algorithm.until that works with non-rewindable input
// ranges.

auto readUntil(R,E)(ref R r, E sentinel)
  if (isInputRange!R && isInputRange!E &&
      isScalarType!(ElementType!E) && isScalarType!(ElementType!R))
{
  alias ElementType!R T;

  //----------------------------------------------------

  final class ReadUntil
  {
    //------------------------------------

    bool empty = false;

    //------------------------------------

    @property T front()
    {
      if (idx < length) return sentinel[idx];
      return r.front;
    }

    //------------------------------------

    void popFront()
    {
      if (!empty)
      {
        if (idx < length)
        {
          ++idx;
          if (idx == length)
          {
            idx = length = 0;
            sentinelCheck();
          }
        }
        else
        {
          r.popFront();
          sentinelCheck();
        }
      }
    }

    //------------------------------------

    void sentinelCheck()
    {
      if (r.empty) { empty = true; return; }
      if (r.front != sentinel[0]) return;

      do
      {
        r.popFront();
        ++length;
        if (r.empty) break;
      } while (length < sentinel.length && r.front == sentinel[length]);

      if (length == sentinel.length)
        empty = true;
    }

    //------------------------------------

    private:
      size_t length = 0;
      size_t idx = 0;
  }

  return new ReadUntil();
}

//----------------------------------------------------------------------------

unittest
{
  ubyte[] txt = cast(ubyte[]) "acabacbxyz".dup;

  auto buff = appender!(ubyte[]);

  auto r1 = inputRangeObject(txt);

  auto u = readUntil(r1,"acb");
  u.copy(buff);
  assert(cast(char[])(buff.data) == "acab");
  buff.clear();
  r1.copy(buff);
  assert(cast(char[])(buff.data) == "xyz");
}

