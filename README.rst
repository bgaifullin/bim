Banking Module
==============

.. image:: https://travis-ci.org/bgaifullin/bim.svg?branch=master
    :target: https://travis-ci.org/bgaifullin/bim

The test project which shows how to use wsql [1]_  and wsql-sdk [2]_  to build complicated system by using
mysql or mariadb with unit-tests and without any kind of ORM.


Project Structure
-----------------
* src/schema  - contains the database schema (SQL code of stored procedures and table declarations)
* bim/models - the auto generated API to work with stored procedures
* bim/tests  - the unit-tests for models.



Commands
--------

* Deploy schema

  ``wsql-trans src/scheme/bank.sql -d DEBUG:<debug> | mysql -u <username>``

* Generate Models

  ``wsql-trans src/scheme/bank.sql | wsql-codegen -l python3_aio -o bim/models --sep '::'``


.. [#] https://github.com/websql/wsql
.. [#] https://github.com/WebSQL/sdk
