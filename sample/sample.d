//Written in the D programming language
/*
 * Sample for jaypha.inet
 *
 * Copyright (C) 2015 Jaypha
 *
 * Distributed under the Boost Software License, Version 1.0.
 * (See http://www.boost.org/LICENSE_1_0.txt)
 *
 * Authors: Jason den Dulk
 */

module sample;

import jaypha.inet.email;
import std.array;
import std.stdio;

void main(string args[])
{
  Email email;

  email.text = "Main body part";
  email.html = "<p>Main body part</p>";

  email.subject = "Subject";
  email.from = Mailbox("jason@jaypha.com.au", "Jason den Dulk");
  email.to = [ Mailbox("anyone@anything.net") ];

  auto a = appender!string();
  email.copy(a);
  writeln(a.data);
}
