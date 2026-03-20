# FAO DynaStore — Geospatial Data Infrastructure

**Organization:** FAO (Food and Agriculture Organization of the United Nations)
**Author:** Carlo Cancellieri (Lead Software Engineer, architect)
**Period:** 2020–present
**Status:** Production — 30,000+ geospatial records, 99.9% SLA

## Overview

DynaStore is FAO's cloud-native geospatial data infrastructure, supporting the Organisation's Hand-in-Hand Initiative. It serves as the central platform for storing, cataloguing, and distributing geospatial data across FAO's programmes.

## Key Features

- **30,000+ geospatial records** with 99.9% SLA
- **OGC STAC standard** — SpatioTemporal Asset Catalog for discovery and access
- **Remote Sensing Portal** — Built on FastAPI + Elasticsearch
- **Cloud-native** — GCP, Kubernetes, Terraform
- **Standards-compliant** — OGC WMS/WFS, STAC, ISO 19115 metadata

## Technology Stack

- Python (FastAPI), TypeScript (React)
- Elasticsearch, PostgreSQL/PostGIS
- Google Cloud Platform, Kubernetes
- OGC STAC, WMS/WFS/WCS
- Terraform for infrastructure-as-code
