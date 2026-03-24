# Specification: integration-url-capture-artifact-collection

## Purpose

Define artifact-collection requirements for URL-capture org-roam outputs.

## ADDED Requirements

### Requirement: URL-capture artifacts are collected with baseline/new separation
The integration suite SHALL collect URL-capture org-roam output files into run results and SHALL preserve visibility of which files are baseline fixtures versus newly generated capture files.

#### Scenario: URL-capture org-roam files are copied to run artifacts
- **WHEN** artifact collection runs after URL-capture execution
- **THEN** org-roam files relevant to URL capture MUST be copied into the run-results artifact set

#### Scenario: Baseline fixtures are distinguishable from generated files
- **WHEN** inspecting collected run artifacts
- **THEN** operators MUST be able to distinguish pre-existing baseline fixture files from newly generated capture files

#### Scenario: Trusted URL outputs remain inspectable post-run
- **WHEN** a run completes with pass or fail status
- **THEN** collected artifacts MUST allow post-mortem inspection of trusted-URL `#+ROAM_REFS`, `Source:` links, and umbrella-ID links
