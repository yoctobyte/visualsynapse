What is it
Visual synapse clients are a set of components that wrap various protocols of the synapse tcp/ip library.
Visual synapse server are a set of server implementations, currently a HTTP and a FTP server are added.

Installation:

Automatic using package (includes latest synapse, visual synapse clients and server)
Open the visual_synapse.dpk file. works on D7, may work for other delphi too. Compile it.

Manual
If you have already installed (other version) of synapse: install the seperate components. `visualsyapse.pas` Is self-containing. Visual server components are in resp.pas file.

Usage - Visual Clients
Most components are relative straight forward. You internet commands got in queue in will be handled in a background thread. Most components can handle multiple simultanious threads. IPHelper is a class that fetches a couple of network statistics. A pointer to userdate can accompany each command and is available on each callback. 

Usage - Visual Servers
Generally they are very flexible. They can be set up to run in automic mode (server a directory etc) or manual mode, where the app gets a callback for each command. You can also freely configure which commands run automatic, which not. Callbacks can be requested te be called thread-safe, but also configured to run in server thread, where the host application provides its own synchronization methods.

Stability
Both clients and servers are used in live, and some on production system. Various personal projects and (at least) one open-source project uses visual synapse as base.

Issues
In rare cases, the FTP server seems to have some issues on neverfinishing threads, probably in client side terminated passive port commands. Besides a small memory leak this is no issue when running. It may cause AV's on shutdown. Situations are rare and seem to only happen on heavy load and when running for longer times. Will be looked at.
Logging should be improved.

Release
0.50 As stable as possible, made sure all resources and a .dpk file are in the zip package. Included synapse release.


Using SSL
Both clients and servers need some kind of encryption library.. Visual Synapse defaults to using openSSL. You can download the libraries from here: http://synapse.ararat.cz/files/crypt/
Visual synapse can easily be adapted to use another encryption library, just change to uses clause pointing to open_ssl and point it to another synapse secure layer plugin. In future visual synapse may hold a compiler switch or so to to this.

Using a secure server
You should point the visual server to your private and public certificates, and optianaly a signing certificate.
This file http://synapse.ararat.cz/files/synacert.zip holds sample certificates, and all instructions how to create your own.
The Visual server components have clear properties to fill in those certificates.

License
The license is a "Modified Artistic License", which is almost a BSD license with some voluntary nonsens added. It is compatible with BSD, GPL and other open source licenses. 

Documentation and website
I am not really satisfied with current wiki, at least needs a better look and also a better wysiwyg editor. Anyhow, in the seperate pieces of docs you should find enough infarmation to get started.
http://visualsynapse.sourceforge.net/

Overall design - self reflection of the author
* Visualsynapse clients are 'mature' in the sense of stability. More protocols like ftp and pop3 clients would be welcome additions. visualsynapse.pas got huge, it should be split into multiple parts. Class design seems good. Job queing proven to be stable. 
* Visual HTTP Server got great. It is fast enough, serves php and other stuff. May be some incompatability on PHP environment variables may be filled (or PHP is unsure about server configuration). Seems have issue on large(!) file uploads / post requests, maybe client browser incompatability (centent-length missing, slow connection, whatever), investigating.
* automatic 'www' prefic for multiple virtual domain handling would be welcome.
* FTP server behaves extremely well, has good compatability with clients. Nice feauture would be to map logged-in user to system file access rights (currently files are accessed under server privileges, it may be possible for a thread to impersonate a specific user).
* Authentication is has support for both password files and NT user authentication. Callback of course also possible, so that you can easy match a user database in your local database. Lacks support for linux PAM authetication.
* Simple TCP server should be made more convenient and added as component.

