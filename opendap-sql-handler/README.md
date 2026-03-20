# OPeNDAP Hyrax SQL Handler

**Author:** Carlo Cancellieri (principal author)
**Period:** Google Summer of Code 2009–2010
**Mentors:** Patrick West, James Gallagher (OPeNDAP Inc.)
**License:** LGPL v2.1
**Status:** Still actively maintained and in production — last push November 2025

## Overview

The SQL Handler is a C++ BES module that adds relational database support to the OPeNDAP Hyrax back-end server. It enables SQL/ODBC database access through the OPeNDAP Data Access Protocol (DAP), allowing relational data to be served alongside scientific datasets (netCDF, HDF5, FITS) through a unified interface.

This was developed as part of Google Summer of Code 2009 and 2010, under the OPeNDAP organization.

## Architecture

The handler connects to any ODBC-compatible database and exposes tables as OPeNDAP datasets:

- **SQLRequestHandler** — Activates the handler and routes fill_xxx_func calls
- **SQLResponseHandler** — Central dispatcher deciding which components to activate
- **SQLCacheManager** — Manages data storage/retrieval with caching support
- **SQLDefinitionStorage** — Stores/retrieves definitions as SQL VIEWs
- **SQLConnector (ODBC)** — Connects to databases via unixODBC drivers
- **Smart Memory Management** — Custom C++ template library for safe heap/stack management

## Supported Databases

- PostgreSQL
- MySQL
- SQLite
- MongoDB (via ODBC)
- Any ODBC-compatible RDBMS

## Key Features

- Transparent integration: users query datasets using standard DAP commands (`GET DAS/DDS/DATA FOR DEFINITION`)
- Dataset files (.sql) configure database connections and SQL queries
- Constraint expressions supported for server-side filtering
- Pluggable architecture via C++ templates for custom actions and type factories
- Smart memory management namespace with shared pointers and safe containers

## Documentation (in this repo)

| File | Description |
|------|-------------|
| [docs/SqlHandler.ppt](docs/SqlHandler.ppt) | Core architecture and design |
| [docs/UseCases.ppt](docs/UseCases.ppt) | Use cases with screenshots of Hyrax serving SQL data |
| [docs/FutureWorks.ppt](docs/FutureWorks.ppt) | Future plans: caching, definition storage, aggregation |
| [docs/Utils.ppt](docs/Utils.ppt) | Smart memory management utilities |

## Deployments

- **FAO** — Food and Agriculture Organization of the United Nations
- **NATO / NURC** — NATO Undersea Research Centre, La Spezia
- **LaMMa** — Laboratory of Monitoring and Environmental Modelling, Florence

## Links

- [Source code (GitHub)](https://github.com/OPENDAP/sql_handler)
- [OPeNDAP](https://www.opendap.org/)
- [Hyrax Data Server](https://www.opendap.org/software/hyrax-data-server)
- [Google Summer of Code](https://summerofcode.withgoogle.com/)

## Screenshots

See the [images/](images/) directory for screenshots of the handler in action, including:
- BES loaded modules showing sql_handler
- OLFS browser interface serving SQL data
- HTML, ASCII, and constrained query views
- Class diagrams (SQLConnector)
- OPeNDAP SCM architecture
