// Written in the D language
/*
 * Code for creating and sending emails.
 *
 * Copyright (C) 2014 Jaypha
 *
 * Distributed under the Boost Software License, Version 1.0.
 * (See http://www.boost.org/LICENSE_1_0.txt)
 *
 * Authors: Jason den Dulk
 */

module jaypha.inet.email;

import jaypha.types;

public import jaypha.inet.imf.writing;
import jaypha.inet.mime.writing;
import jaypha.inet.mime.content_disposition;

import std.file;
import std.process;
import std.array;
import std.stdio;
import std.range;

//----------------------------------------------------------------------------

struct Email
{
  struct Attachment
  {
    string name;
    string mimeType;
    ByteArray content;
    string fileName;
  }

  private MimeHeader[] headers;
  void addHeader(string name, string fieldBody)
  { headers ~= unstructuredHeader(name,fieldBody); }

  string subject;
  Mailbox from;
  Mailbox[] to, cc, bcc;

  string text, html;

  Attachment[] attachments;

  //---------------------------------------------------------

  void copy(R) (R range) if (isOutputRange!(R,ByteArray))
  {
    auto entity = build();
    entity.copy(range);
  }

  //---------------------------------------------------------

  version(linux)
  {
    void sendmail()
    {
      auto entity = build();

      auto pipes = pipeProcess(["sendmail","-t","-i"]);
      auto wout = wOut(pipes.stdin);
      entity.copy(wout);
      //entity.copy(pipes.stdin);
      pipes.stdin.close();
      wait(pipes.pid);
    }
  }


  //---------------------------------------------------------
  // throws CurlException on failure.
  
  void send(string host = "smtp://localhost", string authAccount = null, string authPass = null)
  {
    import std.net.curl;
    auto smtp = SMTP(host);
    if (authAccount)
      smtp.setAuthentication(authAccount, authPass);

    auto entity = build();

    string[] r;
    foreach (b; to)
      r ~= b.address;
    foreach (b;cc)
      r ~= b.address;
    foreach (b;bcc)
      r ~= b.address;
    smtp.mailTo(cast(const(char)[][])r);
    smtp.mailFrom = from.address;
    smtp.message = entity.asString;
    smtp.perform();
  }

  //---------------------------------------------------------
  // Constructs the IMF document for the email. The mime
  // entities themselves handle the serialisation.
  
  private MimeEntity build()
  {
    MimeEntity entity;

    if (!attachments.empty)
    {
      entity = getMultiPart("mixed");
      entity.content.bodParts ~= getMessagePart();
      foreach (a;attachments)
        entity.content.bodParts ~= getAttachmentPart(a);
    }
    else
      entity = getMessagePart();

    entity.headers ~= mimeVersion;

    entity.headers ~= unstructuredHeader("Subject",subject);
    entity.headers ~= addressHeader("From", [ from ] );
    if (!to.empty) entity.headers ~= addressHeader("To", to);
    if (!cc.empty) entity.headers ~= addressHeader("Cc", cc);
    if (!bcc.empty) entity.headers ~= addressHeader("Bcc", cc);
  
    entity.headers ~= headers;
    
    return entity;
  }

  //---------------------------------------------------------
  // Creates an entity for the message, and fills it with the
  // email message contents.

  private MimeEntity getMessagePart()
  {
    if (!html.empty)
    {
      if (!text.empty)
      {
        auto entity = getMultiPart("alternate");
        entity.content.bodParts ~= getHtmlPart();
        entity.content.bodParts ~= getTextPart();
        return entity;
      }
      else
        return getHtmlPart();
    }
    else
      return getTextPart();
  }

  //---------------------------------------------------------
  // Creates a mime entity from the text component.

  private MimeEntity getTextPart()
  {
    MimeContentType ct;
    ct.type = "text/plain";
    ct.parameters["charset"] = "UTF-8";
    
    auto entity = MimeEntity(ct, true);
    entity.encoding = "8bit";

    entity.content.bod = cast(ByteArray) text;

    return entity;
  }

  //---------------------------------------------------------
  // Creates a multipart mime entity of the given subtype.

  private MimeEntity getMultiPart(string subType)
  {
    MimeContentType ct;
    ct.type = "multipart/"~subType;
    auto entity = MimeEntity(ct, true);
    return entity;
  }

  //---------------------------------------------------------
  // Creates a mime entity from the HTML component.

  private MimeEntity getHtmlPart()
  {
    MimeContentType ct;
    ct.type = "text/html";
    ct.parameters["charset"] = "UTF-8";
    
    auto entity = MimeEntity(ct, true);
    entity.encoding = "8bit";

    entity.content.bod = cast(ByteArray) html;

    return entity;
  }

  //---------------------------------------------------------
  // Creates a mime entity for an attachment.

  private MimeEntity getAttachmentPart(ref Attachment a)
  {
    MimeContentType ct;
    ct.type = a.mimeType;
    MimeContentDisposition disp;
    if (ct.type[0..5] != "image")
      disp.type = "attachment";
    disp.parameters["filename"] = a.name;
    
    auto entity = MimeEntity(ct, true);
    entity.headers ~= disp.toMimeHeader(true);
    entity.encoding = "base64";
    if (!a.content.empty)
      entity.content.bod = a.content;
    else
      entity.content.bod = cast(ByteArray) read(a.fileName);

    return entity;
  }
}

// Quick and dirty wrapper to make files act as ranges.

struct wOut
{
  File file;

  void put(ByteArray s) { file.rawWrite(s); }
}

