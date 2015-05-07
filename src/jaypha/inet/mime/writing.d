//Written in the D programming language
/*
 * MIME entity writing utility
 *
 * Copyright (C) 2013 Jaypha
 *
 * Distributed under the Boost Software License, Version 1.0.
 * (See http://www.boost.org/LICENSE_1_0.txt)
 *
 * Authors: Jason den Dulk
 */

module jaypha.inet.mime.writing;

public import jaypha.inet.mime.header;
public import jaypha.inet.mime.contentType;
import jaypha.inet.imf.writing;

import std.base64;
import std.algorithm;

import jaypha.types;
import jaypha.range;
import jaypha.rnd;

// Use this struct specifically for writing.
// To read MIME entities, use jaypha.inet.mime.reading.mimEntityReader

// A MIME entity has two parts, the headers and the body. The headers are
// provided by MimeHeader. The body can be either flat content (type "Single")
// or a list of MIME entities (type "Multi"). MIME entities that are multiple
// are identified by a mime-type of "mulitpart".

// Serialisation is performed by copy(), which writes the entity to the given
// output range, performing any needed formatting and encoding.

// The definition of MIME entities are convered by several RFC documents. See
// rfc.txt for a list of these documents.

struct MimeEntity
{
  enum Type { Single, Multi };

  Type entityType;

  MimeHeader[] headers;
  string encoding = "8bit";
  string encoded;

  string boundary;
  union Content
  {
    ByteArray bod; // Cannot use 'body' as it is a reserved word.
    MimeEntity[] bodParts; // For the sake of consistency.
  }
  Content content;

  //-------------------------------------------------------

  this(MimeContentType contentType, bool wrap = false)
  {
    if (contentType.type.startsWith("multipart"))
    {
      entityType = Type.Multi;
      boundary = rndString(20);
      contentType.parameters["boundary"] = boundary;
    }
    else
      entityType = Type.Single;

    headers = [ contentType.toMimeHeader(wrap) ];
  }

  //-------------------------------------------------------

  @property string asString()
  {
    auto a = appender!string();
    copy(a);
    return a.data;
  }

  //-------------------------------------------------------

  void copy(R)(R range) if (isOutputRange!(R,ByteArray))
  {
    headers ~= MimeHeader("Content-Transfer-Encoding",encoding);
    foreach (h;headers)
      range.put(cast(ByteArray)h.toString());
    range.put(cast(ByteArray)MimeEoln);

    if (entityType == Type.Multi)
    {
      foreach (bodPart; content.bodParts)
      {
        range.put(cast(ByteArray)"--");
        range.put(cast(ByteArray)boundary);
        range.put(cast(ByteArray)MimeEoln);
        bodPart.copy(range);
      }
      range.put(cast(ByteArray)"--");
      range.put(cast(ByteArray)boundary);
      range.put(cast(ByteArray)"--");
      range.put(cast(ByteArray)MimeEoln);
    }
    else
    {
      switch (encoding)
      {
        case "base64":
          byChunk(cast(ByteArray)Base64.encode(content.bod),ImfRecLineLength).join(cast(ubyte[])MimeEoln).copy(range);
          break;
        case "8bit":
        case "7bit":
        case "binary":
          content.bod.copy(range);
          range.put(cast(ByteArray)MimeEoln);
          break;
        case "quoted-printable":
          content.bod.copy(range); // TODO
          break;
        default:
          throw new Exception("Unknown encoding");
      }
    }
  }
}

/+
ByteArray quotePrintableEncode(ByteArray input)
{
        // Replace non printables
        $input    = preg_replace('/([^\x20\x21-\x3C\x3E-\x7E\x0A\x0D])/e', 'sprintf("=%02X", ord("\1"))', $input);
        $inputLen = strlen($input);
        $outLines = array();
        $output   = '';

        $lines = preg_split('/\r?\n/', $input);
        
        // Walk through each line
        for ($i=0; $i<count($lines); $i++) {
            // Is line too long ?
            if (strlen($lines[$i]) > $lineMax) {
                $outLines[] = substr($lines[$i], 0, $lineMax - 1) . "="; // \r\n Gets added when lines are imploded
                $lines[$i] = substr($lines[$i], $lineMax - 1);
                $i--; // Ensure this line gets redone as we just changed it
            } else {
                $outLines[] = $lines[$i];
            }
        }
        
        // Convert trailing whitespace		
        $output = preg_replace('/(\x20+)$/me', 'str_replace(" ", "=20", "\1")', $outLines);

        return implode("\r\n", $output);
    }

+/
