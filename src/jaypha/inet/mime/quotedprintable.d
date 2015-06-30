//Written in the D programming language
/*
 * MIME Quoted Printable Encoding.
 *
 * Copyright (C) 2013 Jaypha
 *
 * Distributed under the Boost Software License, Version 1.0.
 * (See http://www.boost.org/LICENSE_1_0.txt)
 *
 * Authors: Jason den Dulk
 */

module jaypha.inet.mime.quotedprintable;
import jaypha.inet.mime.header;

import jaypha.types;

import std.ascii;
import std.array;
import std.string;

//----------------------------------------------------------------------------
// input is an 8-bit code
// output is an ASCII string.
// See http://tools.ietf.org/html/rfc2045#section-6.7.

string quotedPrintableEncode(ByteArray input, size_t maxLength = 76)
{
  auto output = appender!(string[])();
  auto lines = splitLines(cast(string)input);//lineSplitter(input);

  foreach (line;lines)
  {
    auto qLine = appender!string();
    size_t lineLength = 0;
    string append;

    foreach (i,c; line)
    {
      if (c == '=')
        append = "=3D";
      else if (c == ' ' && i == line.length-1)
        append = "=20";
      else if (isPrintable(c))
        append = cast(string)[c];
      else
        append = format("=%02X",c);

      if ((lineLength + append.length > maxLength-1))
      {
        qLine.put("=");
        qLine.put(MimeEoln);

        lineLength = 0;
      }
      qLine.put(append);
      lineLength += append.length;
    }
    output.put(qLine.data);
  }

  return output.data.join(MimeEoln);
}

unittest
{
  //import std.stdio;

  char c = 3;
  auto str = cast(ByteArray)"abcde=fghi";

  auto qStr = quotedPrintableEncode(str);
  assert(qStr == "abcde=3Dfghi");
  str ~=c;
  qStr = quotedPrintableEncode(str);
  assert(qStr == "abcde=3Dfghi=03");

  str = cast(ByteArray)"abcde\nfghi\ngthy";
  qStr = quotedPrintableEncode(str);
  assert(qStr == "abcde\r\nfghi\r\ngthy");

  
  str = cast(ByteArray)"12345678901234567890123456789012345678901234567890123456789012345678901234567890";
  qStr = quotedPrintableEncode(str);
  assert(qStr == "123456789012345678901234567890123456789012345678901234567890123456789012345=\r\n67890");

  str = cast(ByteArray)"1234567890123456789012 \n34567890";
  qStr = quotedPrintableEncode(str);
  assert(qStr == "1234567890123456789012=20\r\n34567890");

  str = cast(ByteArray)"123456789012345678901234567890123456789012345678901234567890123456789012345 \n67890";
  qStr = quotedPrintableEncode(str);
  assert(qStr == "123456789012345678901234567890123456789012345678901234567890123456789012345=\r\n=20\r\n67890");
}
