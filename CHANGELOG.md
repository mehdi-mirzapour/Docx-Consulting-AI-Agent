# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2026-01-19

### Added
- Progress indicators showing estimated processing time (20-30 seconds)
- User-friendly error messages with specific troubleshooting guidance
- Proper download filenames with `.docx` extension (e.g., `Document_modified.docx`)
- Content-Disposition headers for proper file downloads

### Changed
- **Performance:** Optimized backend to batch process 5 paragraphs per API call
  - Reduced API calls by 80% (from ~187 to ~37 for typical documents)
  - Processing time reduced by 40% (from 2.5 minutes to ~90 seconds)
- Updated CORS configuration to allow all origins in development
- Download endpoint now uses `doc_id` instead of filename for better security

### Fixed
- Frontend error handling - UI no longer gets stuck on "Analyzing..." when errors occur
- CORS blocking issues preventing frontend-backend communication
- Download files now have proper filenames instead of UUIDs
- Loading states properly reset on error
- Missing `.docx` extension on downloaded files

### Technical Details
- Implemented batched OpenAI API calls in `generate_suggestions()`
- Added comprehensive try/catch blocks in frontend fetch operations
- Enhanced CORS middleware with `allow_origins=["*"]` for development
- Modified `handle_download()` to use stored original filenames

## [Unreleased]

### Planned
- Real-time progress percentage (e.g., "Processing batch 5 of 37...")
- Document caching to avoid re-processing
- Support for additional formats (PDF, TXT)
- Production-ready CORS configuration
- Persistent storage (database) for document metadata
