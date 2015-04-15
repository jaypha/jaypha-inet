Jaypha Inet
===========

This project provides a struct to easily construct emails. Also provides a
number of structures for reading and writing IMF/MIME documents in general.

Documentation
-------------

See doc.html for reference documentation.

Modules
-------

All my modules are kept under the 'jaypha' umbrella package. The jaypha.inet
library consists of the following modules.

* jaypha.inet.email
* jaypha.inet.imf.writing
* jaypha.inet.mime.header
* jaypha.inet.mime.content_disposition
* jaypha.inet.mime.writing
* jaypha.inet.mime.reading

License
-------

Distributed under the Boost License.

Contact
-------

jason@jaypha.com.au

Todo
----

Finish documentation.
Implement "quoted-printable" encoding.

Current Problems
----------------

Unable to get std.net.curl.SMTP to work for anything other than "localhost".
