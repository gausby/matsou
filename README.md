Matsou
======

Eventually this will be a helper library for working with Riak CRDT types. It will provide:

- [ ] Schemas

  Fields on the CRDT should be defined on a module with a Macro. This should ensure that all data put into the data store follow the same structure. Validation types should be defined here.

- [ ] Validation of data

- [ ] A pipeline interface for altering data

  The Matsou data should be short lived: Pulled from the database, altered and put back.

- [ ] Methods for persisting the changes to the database

  The generated module should have a save function that first validate the dirty data and push the updated values to the data store. Should return `:ok` if successful and and error-tuple if non-successful.

Installation
------------

If this becomes usable it will get published to Hex. Until then it should just be installed directly from GitHub.

* * *

Riak and Basho are the registered trademark of Basho. This project has no affiliation with Basho.
