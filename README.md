# Carlo Cancellieri — Project Portfolio

Technical documentation, presentations, and architecture artifacts from 20+ years of software engineering across international organizations.

## Projects

### [OPeNDAP SQL Handler](opendap-sql-handler/) — GSoC 2009–2010
C++ BES module enabling SQL/ODBC database access through the OPeNDAP Hyrax data access protocol. Selected twice for Google Summer of Code. **Still actively maintained and in production use 15+ years later.**

- Supports PostgreSQL, MySQL, SQLite, MongoDB via ODBC
- Output through netCDF, HDF5, FITS, ASCII
- Deployed at FAO, NATO, NURC, LaMMa
- [Live repository](https://github.com/OPENDAP/sql_handler)

### [Keystone IAM Platform](keystone/) — FAO, 2020–present
Unified Identity and Access Management platform for the UN Food and Agriculture Organization, serving 25,000+ users across 50+ countries under the Hand-in-Hand Initiative.

- RBAC/ReBAC authorization model
- Cloud-native on GCP with Kubernetes
- Cross-divisional integration across FAO Statistics, IT, and regional offices

### [GeoServer Contributions](geoserver/) — GeoSolutions, 2010–2014
Core contributor to GeoServer, the leading open-source geospatial server. Delivered solutions for FAO, NATO, and international research institutions.

### [FAO DynaStore](fao-dynastore/) — FAO, 2020–present
FAO's geospatial data infrastructure — cloud-native platform serving 30,000+ geospatial records with 99.9% SLA. Built on OGC STAC standard.

### [MCP Skill Hub](https://github.com/ccancellieri/mcp-skill-hub) — Personal Project, 2026

A local MCP server that gives Claude Code semantic skill search, cross-session task memory, and zero-token command interception — all powered by Ollama running entirely on your machine.

- Semantic search across 1,000+ skills using Ollama embeddings (nomic-embed-text)
- UserPromptSubmit hook intercepts task commands before Claude sees them — zero API tokens
- Cross-session task memory with local LLM compaction (deepseek-r1)
- Three-signal learning: teachings, feedback, session history
- Token savings profiling: tracks estimated Claude API cost reduction
- Install with `./install.sh` — no external services required

### [Planner App](planner-app/) — Personal Project, 2026
AI-powered leisure activity planner for iOS (Scriptable). Uses LLM APIs (Claude, Gemini, Perplexity) to discover activities and generates interactive Leaflet maps — fully on-device.

- [Live repository](https://github.com/ccancellieri/plan-viewer)

### [Presentations](presentations/)
Conference talks, technical presentations, and training materials.

## About

Carlo Cancellieri is a Lead Software Engineer at FAO (United Nations), OGC Member, ISO-TC211 contributor, and holds an MBA with First Class Honours (100/100). 1,000+ GitHub contributions per year across @un-fao, @FAOSTAT, @ISO-TC211, and @OPENDAP.

## License

Documentation and presentations are shared for reference and portfolio purposes. Original software projects retain their respective licenses (LGPL for sql_handler, etc.).
