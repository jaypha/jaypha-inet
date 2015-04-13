//Written in the D programming language
/*
 * Code for writing IMF.
 *
 * Copyright (C) 2014 Jaypha
 *
 * Distributed under the Boost Software License, Version 1.0.
 * (See http://www.boost.org/LICENSE_1_0.txt)
 *
 * Authors: Jason den Dulk
 */

module jaypha.inet.imf.writing;

public import jaypha.inet.mime.header;

import std.array;
import std.string;

enum ImfMaxLineLength = 998;
enum ImfRecLineLength = 76;

//-----------------------------------------------------------------------------
// Mailbox type used in address based headers (from, to, cc, etc)

struct Mailbox
{
  string address;
  string name;
  @property string asString()
  { 
    if (name.empty) return address;
    else return name ~ " <" ~ address ~ ">";
  }
}


//-----------------------------------------------------------------------------
// Performs folding to keep lines to a certian maximum length.

string imfFold(string content, ulong additional, out ulong lastLineLength)
{
  auto a = appender!string();

  while (content.length+additional > ImfMaxLineLength)
  {
    auto i = lastIndexOf(content[0..ImfMaxLineLength-additional],' ');
    assert(i != 0);

    a.put(content[0..i]);
    a.put(MimeEoln);
    content = content[i..$];
    additional = 0;
  }
  a.put(content);
  lastLineLength = content.length;

  return a.data;
}

//-----------------------------------------------------------------------------
// Standard function for unstructured headers.

MimeHeader unstructuredHeader(string name, string fieldBody)
{
  MimeHeader header;
  header.name = name;
  ulong len;

  if (name.length + fieldBody.length + 1 > ImfMaxLineLength)
    header.fieldBody = imfFold(fieldBody,name.length+1, len);
  else
    header.fieldBody = fieldBody;
  return header;
}

//-----------------------------------------------------------------------------
// Standard function for address (from,to,cc,bcc) headers.

MimeHeader addressHeader(string name, Mailbox[] addresses)
{
  MimeHeader header;
  header.name = name;

  string[] list;
  ulong runningLength = name.length+1;
  foreach (r;addresses)
  {
    string n = " ";
    n ~= r.asString;

    if (runningLength + n.length > ImfMaxLineLength)
    {
      runningLength = -2;
      n = MimeEoln ~ n;
    }
    list ~= n;
    runningLength += n.length+1;
  }
  header.fieldBody = list.join(",");
  return header;
}
