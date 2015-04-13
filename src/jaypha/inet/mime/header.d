//Written in the D programming language
/*
 * MIME header
 *
 * Copyright (C) 2013 Jaypha
 *
 * Distributed under the Boost Software License, Version 1.0.
 * (See http://www.boost.org/LICENSE_1_0.txt)
 *
 * Authors: Jason den Dulk
 */

module jaypha.inet.mime.header;

enum MimeEoln = "\r\n";

//-----------------------------------------------------------------------------
// Basic form of an Mime/Imf header

struct MimeHeader
{
  string name;
  string fieldBody;
  string toString() { return .toString(name,fieldBody); }
}

//-----------------------------------------------------------------------------
// Basic format for headers <name>: <fieldBody>/r/n

string toString(string name, string fieldBody)
{
  return (name~": "~fieldBody~MimeEoln);
}

//-----------------------------------------------------------------------------

@property MimeHeader mimeVersion() { return MimeHeader("MIME-Version","1.0"); }
